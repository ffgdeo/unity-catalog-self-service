# Reference Architecture — Governed UC Provisioning

## End-state, one picture

```mermaid
flowchart LR
  user["Engineer<br/>(self-service)"]
  form["Provisioning form<br/>(Backstage / ServiceNow /<br/>GH Issue Form — your choice)"]
  pr["GitHub PR<br/>opened by form action<br/>touches /catalogs or /teams"]
  co["CODEOWNERS routing<br/>auto-assigns reviewer"]
  owner["Data owner<br/>OR team lead<br/>(NOT platform team)"]
  ci["CI runner<br/>terraform plan + apply"]
  sp["Scoped service principal<br/>MANAGE on owned catalogs only<br/>no account_admin"]
  uc["Unity Catalog<br/>catalog / schema / grant /<br/>SP / cluster policy"]
  ws["Databricks workspace<br/>(team assigned via SCIM group)"]

  user -->|fills form: 'new team Foo'| form
  form -->|emits TF block| pr
  pr --> co
  co -->|requests review| owner
  owner -->|approves| pr
  pr -->|merged| ci
  ci -->|auth M2M OAuth| sp
  sp -->|applies| uc
  uc --> ws

  classDef ext fill:#f4f4f4,stroke:#999;
  classDef gh fill:#e8f0fe,stroke:#3a76d8;
  classDef sec fill:#fef3e8,stroke:#d87a3a;
  classDef dbx fill:#e8f5e8,stroke:#3aa53a;

  class user,form ext;
  class pr,co,owner,ci gh;
  class sp sec;
  class uc,ws dbx;
```

**Trust boundaries (numbered, left to right):**
1. **User ↔ form** — auth via corporate SSO, no DBX access from user directly
2. **PR ↔ CODEOWNERS** — GitHub branch protection rules enforce this; no admin override
3. **CI ↔ SP** — short-lived OAuth tokens, SP cannot escalate beyond catalogs it owns
4. **SP ↔ UC** — UC privilege model is the final enforcement layer

The platform team operates **boxes 2 and 3** (the routing config and the SP scope). They do *not* operate boxes 1 (the form) or 4 (UC enforcement) — those are owned by app/security teams and Databricks respectively.

## Identity layer — SCIM and AIM coexistence

```mermaid
flowchart TB
  okta["Okta<br/>(source of truth)"]
  scim["SCIM provisioning<br/>(existing today)"]
  aim["AIM (Automatic Identity Management)<br/>PrPr for Okta on AWS — Apr 2026"]
  acct["Databricks Account"]
  ws1["Workspace A<br/>(legacy)"]
  ws2["Workspace B<br/>(new pattern)"]
  uc["Unity Catalog<br/>users + groups"]

  okta -->|scheduled push:<br/>users + groups| scim
  okta -->|OIDC claims at login:<br/>just-in-time user + group| aim
  scim --> acct
  aim --> acct
  acct -->|identity federation| ws1
  acct -->|identity federation| ws2
  acct --> uc

  classDef idp fill:#fff3cd,stroke:#e6a700;
  classDef prov fill:#cde4ff,stroke:#3a76d8;
  classDef dbx fill:#e8f5e8,stroke:#3aa53a;
  classDef prpr fill:#fce4ec,stroke:#c2185b,stroke-dasharray: 5 5;

  class okta idp;
  class scim prov;
  class aim prpr;
  class acct,ws1,ws2,uc dbx;
```

**Key decisions to make when adopting this pattern:**

| Decision | Option A (lower risk) | Option B (more upside) |
|----------|----------------------|------------------------|
| **AIM enrollment** | Stay on SCIM-only until Okta AIM goes PuPr | Enroll PrPr now, run AIM + SCIM in parallel, retire SCIM later |
| **Group activation** | Use SCIM `active: true` push for all groups | Use AIM `resolveByExternalId` API to activate JIT |
| **Workspace identity federation** | Account-level (recommended either way) | — |

The dashed/pink box is the PrPr-risk part. **Both SCIM and AIM can coexist on the same account** — they aren't mutually exclusive. The choice is whether to layer AIM in *now* or *post-GA*.

**Common gotcha:**
Enabling AIM with SCIM still pushing causes groups to be created twice (once SCIM-pushed, once OIDC-JIT) under different IDs unless `external_id` is set consistently across both systems.
