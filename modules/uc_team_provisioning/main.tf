terraform {
  required_providers {
    databricks = {
      source                = "databricks/databricks"
      configuration_aliases = [databricks.account, databricks.workspace]
      version               = ">= 1.50.0"
    }
  }
}

variable "team_name" {
  type        = string
  description = "Team identifier. Must match an existing IdP-synced group: team-<team_name>."
}

variable "workspace_id" {
  type        = number
  description = "Workspace this team gets assigned to."
}

variable "sandbox_catalog" {
  type        = string
  description = "Catalog where the team's sandbox schema lives (typically a shared 'sandboxes' catalog)."
}

variable "tags" {
  type = map(string)
  validation {
    condition     = contains(keys(var.tags), "cost_center") && contains(keys(var.tags), "team")
    error_message = "tags must include cost_center and team."
  }
}

locals {
  team_group  = "team-${var.team_name}"
  sp_name     = "sp-team-${var.team_name}"
  policy_name = "policy-team-${var.team_name}"
}

resource "databricks_service_principal" "team_sp" {
  provider     = databricks.account
  display_name = local.sp_name
  external_id  = local.team_group
}

resource "databricks_mws_permission_assignment" "ws_assign" {
  provider     = databricks.account
  workspace_id = var.workspace_id
  principal_id = databricks_service_principal.team_sp.id
  permissions  = ["USER"]
}

resource "databricks_mws_permission_assignment" "team_to_workspace" {
  provider     = databricks.account
  workspace_id = var.workspace_id

  principal_id = data.databricks_group.team.id
  permissions  = ["USER"]
}

data "databricks_group" "team" {
  provider     = databricks.account
  display_name = local.team_group
}

resource "databricks_cluster_policy" "team_policy" {
  provider = databricks.workspace
  name     = local.policy_name

  definition = jsonencode({
    "custom_tags.team" = {
      type      = "fixed"
      value     = var.team_name
      hidden    = false
    }
    "custom_tags.cost_center" = {
      type  = "fixed"
      value = var.tags.cost_center
    }
    "node_type_id" = {
      type   = "allowlist"
      values = ["m5d.large", "m5d.xlarge", "m5d.2xlarge"]
    }
    "autoscale.max_workers" = {
      type      = "range"
      maxValue  = 8
      hidden    = false
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
  })
}

resource "databricks_permissions" "policy_use" {
  provider          = databricks.workspace
  cluster_policy_id = databricks_cluster_policy.team_policy.id

  access_control {
    group_name       = local.team_group
    permission_level = "CAN_USE"
  }
}

module "team_sandbox_schema" {
  source = "../uc_schema"

  catalog_name = var.sandbox_catalog
  name         = var.team_name
  owner_group  = local.team_group
}

output "team_sp_id" {
  value = databricks_service_principal.team_sp.application_id
}

output "team_policy_id" {
  value = databricks_cluster_policy.team_policy.id
}

output "sandbox_schema" {
  value = module.team_sandbox_schema.schema_full_name
}
