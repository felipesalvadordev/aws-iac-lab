resource "aws_s3_bucket" "datalake_storage" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_cleanup" {
  bucket = aws_s3_bucket.datalake_storage.id

  rule {
    id     = "clean-results-athena"
    status = "Enabled"

    filter {
      prefix = "athena-results/"
    }

    expiration {
      days = 1 # Delete objects after 1 day
    }
  }
}