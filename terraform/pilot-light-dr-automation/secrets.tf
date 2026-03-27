resource "aws_secretsmanager_secret" "db_password" {
  provider                = aws.primary
  name                    = "${local.config.project_name}-db-password-v2"
  description             = "Password for RDS MySQL"
  recovery_window_in_days = 0 # Allow to delete immediately if needed
}

resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret_version" "db_password_val" {
  provider      = aws.primary
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_password.result
}