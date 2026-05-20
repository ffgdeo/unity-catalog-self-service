resource "databricks_group" "owners" {
  display_name = "finance_prod-owners"
}
resource "databricks_group" "engineers" {
  display_name = "finance_prod-engineers"
}
resource "databricks_group" "readers" {
  display_name = "finance_prod-readers"
}
resource "databricks_group" "gold_readers" {
  display_name = "finance_prod-gold-readers"
}
