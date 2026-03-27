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

resource "aws_iam_role" "backup_role" {
  name = "${local.config.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_policy" "secrets_read_policy" {
  name        = "${local.config.project_name}-secrets-read"
  description = "Permite que a app leia a senha do RDS no Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = [aws_secretsmanager_secret.db_password.arn]
      }
    ]
  })
}

# Role to allow EC2 instances to read secrets from Secrets Manager
resource "aws_iam_role" "ec2_role" {
  name = "${local.config.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach the secrets read policy to the EC2 role
resource "aws_iam_role_policy_attachment" "ec2_secrets_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_read_policy.arn
}


resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.config.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}