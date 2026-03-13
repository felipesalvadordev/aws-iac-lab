resource "aws_glue_catalog_database" "my_database" {
  name = var.glue
}

resource "aws_glue_crawler" "s3_crawler" {
  database_name = aws_glue_catalog_database.my_database.name
  name          = "s3-data-crawler"
  role          = aws_iam_role.glue_service_role.arn
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  s3_target {
    path = "s3://${aws_s3_bucket.datalake_storage.bucket}/raw-data/sales/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE" # Update existing tables in Data Catalog with new schema changes
    delete_behavior = "DEPRECATE_IN_DATABASE" # Mark tables as deprecated instead of deleting them when they are removed from the data source
  }
}