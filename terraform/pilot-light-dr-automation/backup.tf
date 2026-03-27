
resource "aws_backup_vault" "primary_vault" {
  provider = aws.primary
  name     = "${local.config.project_name}-primary-vault"
}

resource "aws_backup_vault" "dr_vault" {
  provider = aws.dr
  name     = "${local.config.project_name}-dr-vault"
}

resource "aws_backup_plan" "rds_backup_plan" {
  provider = aws.primary
  name     = "${local.config.project_name}-rds-plan"

  rule {
    rule_name         = "DailyBackupWithCrossRegionCopy"
    target_vault_name = aws_backup_vault.primary_vault.name
    schedule          = "cron(0 5 * * ? *)" # Every day at 5 AM UTC

    lifecycle {
      delete_after = 1
    }

    # Automatic copy para a vault de DR
    copy_action {
      destination_vault_arn = aws_backup_vault.dr_vault.arn
      lifecycle {
        delete_after = 1
      }
    }
  }
}

# Resources select for backup
resource "aws_backup_selection" "rds_selection" {
  provider     = aws.primary
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "rds-snapshot-selection"
  plan_id      = aws_backup_plan.rds_backup_plan.id
  # Select primary database by the identifier
  resources = [
    aws_db_instance.primary.arn
  ]
}