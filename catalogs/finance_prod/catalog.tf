module "finance_prod" {
  source       = "../../modules/uc_catalog"
  name         = "finance_prod"
  owner_group  = databricks_group.owners.display_name
  storage_root = "s3://test-bucket"
  comment      = "test pr"
  tags = {
    cost_center = "Eng"
    data_domain = "finance"
  }
}
