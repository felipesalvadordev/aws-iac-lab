resource "aws_dynamodb_table" "terraform_lock" {
  provider     = aws.primary
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "LockID"
    type = "S"
  }

  replica {
    region_name = local.config.dr_region
  }

  tags = {
    Name = "Terraform State Lock - Global"
  }
}

resource "aws_s3_bucket" "state_replica" {
  provider      = aws.dr
  bucket        = local.bucket_dr 
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  provider = aws.dr
  bucket   = aws_s3_bucket.state_replica.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket" "state_primary" {
  provider      = aws.primary
  bucket        = local.bucket_primary 
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  provider = aws.primary
  bucket   = aws_s3_bucket.state_primary.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary
  role     = aws_iam_role.replication_role.arn
  bucket   = aws_s3_bucket.state_primary.id

  rule {
    id     = "StateReplicationRule"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.state_replica.arn
      storage_class = "STANDARD"
    }
  }
  
  depends_on = [
    aws_s3_bucket_versioning.primary_versioning, 
    aws_s3_bucket_versioning.replica_versioning
  ]
}