# Approval Routing — CODEOWNERS Pattern

## The principle

Grants on a catalog should be approved by the **owner of that catalog**, not by the platform team. CODEOWNERS makes this enforceable in GitHub.

## Repo layout that makes routing trivial

```
platform-terraform/
├── .github/
│   └── CODEOWNERS
├── catalogs/
│   ├── finance/
│   │   ├── catalog.tf          # uses uc_catalog module
│   │   └── grants.tf           # all grants touching the finance catalog
│   ├── marketing/
│   │   └── ...
│   └── platform/
│       └── ...
├── teams/
│   ├── data-platform/
│   │   └── main.tf             # uses uc_team_provisioning module
│   └── ...
└── modules/                    # the modules in this repo
```

## CODEOWNERS

```
# .github/CODEOWNERS

# Modules are platform-owned — anyone changing the pattern itself needs platform review
/modules/                       @acme/platform-team

# Catalog-scoped changes route to the data owner for that catalog
/catalogs/finance/              @acme/data-owners-finance
/catalogs/marketing/            @acme/data-owners-marketing
/catalogs/platform/             @acme/platform-team
/catalogs/ml/                   @acme/data-owners-ml

# Team folder changes route to the team itself + platform (platform sanity-check on SP/policy creation)
/teams/                         @acme/platform-team
```

## Required branch protection on `main`

- Require a pull request before merging
- **Require review from Code Owners** ← critical
- Require status checks (tf fmt, tf validate, plan)
- Dismiss stale reviews on new commits

This is the magic. The user fills out the form → form opens a PR that touches `/catalogs/finance/grants.tf` → GitHub auto-requests review from `@acme/data-owners-finance` → no one else can approve it.

## CI apply via scoped SP

CI runs `terraform apply` as a service principal that is scoped narrowly:

- `account_admin = false` (never an admin)
- `MANAGE` on the catalogs that this repo manages, granted via TF
- Workspace `USER` on the workspaces the repo deploys to
- No PAT for the workspace; uses M2M OAuth with the account SP

This means even if someone gets a malicious PR merged, the blast radius is bounded by what the SP can do. The SP cannot create new catalogs unless someone separately gave it `CREATE CATALOG` on the metastore.

## What the form emits

A user fills out "Create new team `data-platform`, cost center `ENG-DATA-001`":

The form action opens a PR adding:

```hcl
# teams/data-platform/main.tf
module "team_data_platform" {
  source       = "../../modules/uc_team_provisioning"
  team_name    = "data-platform"
  workspace_id = 1234567890
  tags = {
    cost_center = "ENG-DATA-001"
    team        = "data-platform"
  }
}
```

That's it. The user doesn't write Terraform. They fill in 3 fields. CODEOWNERS routes the PR. Platform team approves.

## What the form is

Doesn't matter. Backstage, ServiceNow, a custom internal portal, or even a GitHub Issue Form with an Actions workflow that opens the PR. **Pick what your platform team already operates** — don't introduce a new tool just for this.
