terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50.0"
    }
  }
}

variable "catalog_name" {
  type = string
}

variable "name" {
  type        = string
  description = "Schema name within the catalog."
}

variable "owner_group" {
  type        = string
  description = "Group that owns this schema (typically the team using it)."
}

variable "reader_groups" {
  type        = list(string)
  default     = []
  description = "Groups with SELECT on tables/views in this schema."
}

variable "comment" {
  type    = string
  default = null
}

resource "databricks_schema" "this" {
  catalog_name = var.catalog_name
  name         = var.name
  comment      = var.comment
  owner        = var.owner_group
  force_destroy = false
}

resource "databricks_grants" "schema_grants" {
  schema = "${databricks_schema.this.catalog_name}.${databricks_schema.this.name}"

  grant {
    principal  = var.owner_group
    privileges = ["ALL_PRIVILEGES"]
  }

  dynamic "grant" {
    for_each = toset(var.reader_groups)
    content {
      principal  = grant.value
      privileges = ["USE_SCHEMA", "SELECT"]
    }
  }
}

output "schema_full_name" {
  value = "${databricks_schema.this.catalog_name}.${databricks_schema.this.name}"
}
