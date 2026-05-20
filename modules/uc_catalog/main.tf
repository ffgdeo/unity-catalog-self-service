terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50.0"
    }
  }
}

variable "name" {
  type        = string
  description = "Catalog name. Convention: <domain>_<env> e.g. finance_prod, marketing_dev"
}

variable "owner_group" {
  type        = string
  description = "Account-level group name that owns this catalog. Approvals will route here via CODEOWNERS."
}

variable "storage_root" {
  type        = string
  description = "External location URL for managed tables. Must already exist."
}

variable "comment" {
  type    = string
  default = null
}

variable "tags" {
  type        = map(string)
  description = "Custom tags. Must include 'cost_center' and 'data_domain'."
  validation {
    condition     = contains(keys(var.tags), "cost_center") && contains(keys(var.tags), "data_domain")
    error_message = "tags must include cost_center and data_domain."
  }
}

resource "databricks_catalog" "this" {
  name           = var.name
  comment        = var.comment
  storage_root   = var.storage_root
  isolation_mode = "ISOLATED"
  force_destroy  = false
}

resource "databricks_grants" "owner" {
  catalog = databricks_catalog.this.name

  grant {
    principal  = var.owner_group
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_catalog_workspace_binding" "binding" {
  for_each       = toset([])
  catalog_name   = databricks_catalog.this.name
  workspace_id   = each.value
  binding_type   = "BINDING_TYPE_READ_WRITE"
}

output "catalog_name" {
  value = databricks_catalog.this.name
}

output "owner_group" {
  value = var.owner_group
}
