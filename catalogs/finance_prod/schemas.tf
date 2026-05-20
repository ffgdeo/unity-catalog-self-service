module "bronze" {
  source        = "../../modules/uc_schema"
  catalog_name  = module.finance_prod.catalog_name
  name          = "bronze"
  owner_group   = databricks_group.engineers.display_name
  reader_groups = [databricks_group.readers.display_name]
}

module "silver" {
  source        = "../../modules/uc_schema"
  catalog_name  = module.finance_prod.catalog_name
  name          = "silver"
  owner_group   = databricks_group.engineers.display_name
  reader_groups = [databricks_group.readers.display_name]
}

module "gold" {
  source        = "../../modules/uc_schema"
  catalog_name  = module.finance_prod.catalog_name
  name          = "gold"
  owner_group   = databricks_group.engineers.display_name
  reader_groups = [
    databricks_group.readers.display_name,
    databricks_group.gold_readers.display_name,
  ]
}
