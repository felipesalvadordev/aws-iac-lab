resource "aws_iam_role" "replication_role" {
  name = "${local.config.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "replication_policy" {
  name = "${local.config.project_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.state_primary.arn]
      },
      {
        Action = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.state_primary.arn}/*"]
      },
      {
        Action = ["s3:ReplicateObject", "s3:ReplicateDelete"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.state_replica.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication_attach" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}