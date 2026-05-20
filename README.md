# Unity Catalog Self-Service Provisioning — Reference Pattern

A reference skeleton for governance-controlled Unity Catalog provisioning. Engineers self-serve via a form, but data owners approve every access change via CODEOWNERS routing on Terraform pull requests.

It is intentionally minimal and opinionated — designed to be lifted and adapted into a platform Terraform repository, not consumed as-is.

## What this solves

Before:
- Anyone with Terraform access could provision catalogs, schemas, grants, service principals
- Approval went to the platform team, not to data owners
- No standardized template — every team rolled their own
- AI agents ended up with read access to data they shouldn't have seen

After:
- A small set of **reusable modules** is the only sanctioned way UC resources get created
- A **form** (Backstage / ServiceNow / GitHub PR template — your choice) emits a TF block that calls these modules
- **CODEOWNERS** on the catalog/schema paths routes PR approval to the data owner, not the platform team
- CI applies via a **scoped service principal** with `MANAGE` on specific catalogs only — no admin token in CI

## Layout

```
modules/
  uc_catalog/                  # create catalog + bootstrap admin grant + owner tag
  uc_schema/                   # create schema under existing catalog + grants
  uc_team_provisioning/        # composite: SP + cluster policy + sandbox schema + workspace assignment

examples/
  new_team/                    # what a form emits when "create new team Foo" is requested

docs/
  approval-routing.md          # CODEOWNERS pattern + per-catalog ownership convention
```

## Approval pattern (the part that doesn't live in TF)

Approval routing is enforced by **CODEOWNERS** in the platform repo, not by TF itself:

```
# .github/CODEOWNERS

# Per-catalog ownership
/catalogs/finance/**     @acme/data-owners-finance
/catalogs/marketing/**   @acme/data-owners-marketing
/catalogs/platform/**    @acme/platform-team

# Anyone touching the modules themselves
/modules/**              @acme/platform-team
```

Branch protection on `main` requires CODEOWNER review → data owners physically must approve grants on their catalog. The platform team only owns *changes to the pattern itself*.

## What the platform team still owns

- The modules in `modules/` (and reviewing PRs that change them)
- The CI service principal and its scope
- Account-level identity setup (SCIM, AIM enrollment, group sync)
- External locations + storage credentials (these are not self-serve)

## What teams own

- Their team folder: `teams/<team_name>/main.tf` calling `uc_team_provisioning`
- Their schemas under their catalog
- Their grant changes within their catalog (PR gets routed back to them via CODEOWNERS)

## Try it: form → PR demo

This repo includes two GitHub Issue Forms that demonstrate the self-service pattern. Each one opens a real PR when submitted:

- **["New team request"](../../issues/new?template=new_team.yml)** — fills in `teams/<team_name>/main.tf` for an existing project
- **["New project catalog request"](../../issues/new?template=new_catalog.yml)** — provisions a full catalog: 4 groups, 3 schemas (bronze/silver/gold), CODEOWNERS entry

The workflows in `.github/workflows/` parse the issue, write the Terraform files, and open a PR for review. In a real deployment the PR would route via CODEOWNERS to the appropriate data owner and CI would apply on merge — here it stops at the PR open step so you can inspect what gets generated.

## What this is not

This is a **reference pattern**, not a turn-key production system. To make it production-ready you would still need to:

- Replace the placeholder `@ffgdeo` in `.github/CODEOWNERS` with real GitHub team handles
- Enable branch protection on `main` with "Require review from Code Owners" turned on
- Stand up a real CI service principal and wire `terraform apply` into the merge workflow
- Configure the `databricks.account` and `databricks.workspace` providers with real credentials
- Pre-provision the external locations and storage credentials referenced by `storage_root`
