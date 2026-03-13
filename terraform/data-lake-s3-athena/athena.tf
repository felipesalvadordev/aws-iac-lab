resource "aws_athena_workgroup" "primary" {
  name = var.athena_work_group
  force_destroy = true
  
  configuration {
    enforce_workgroup_configuration = false
    # Avoid scanning large datasets by setting a bytes scanned cutoff per query
    bytes_scanned_cutoff_per_query = 104857600 # Limit to 100 MB per query
    result_configuration {
      output_location = "s3://${aws_s3_bucket.datalake_storage.bucket}/athena-results/"
    }
  }
}
