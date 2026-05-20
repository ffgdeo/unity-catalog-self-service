terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50.0"
    }
  }
}

provider "databricks" {
  alias   = "account"
  host    = "https://accounts.cloud.databricks.com"
  account_id = "..."
}

provider "databricks" {
  alias = "workspace"
  host  = "https://acme-prod.cloud.databricks.com"
}

module "team_data_platform" {
  source = "../../modules/uc_team_provisioning"

  providers = {
    databricks.account   = databricks.account
    databricks.workspace = databricks.workspace
  }

  team_name       = "data-platform"
  workspace_id    = 1234567890
  sandbox_catalog = "sandboxes"

  tags = {
    cost_center = "ENG-DATA-001"
    team        = "data-platform"
  }
}
