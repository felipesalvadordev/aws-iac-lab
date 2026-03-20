locals {
  config         = jsondecode(file("${path.module}/config.json"))
  bucket_primary = "${local.config.project_name}-terraform-state-${local.config.primary_region}"
  bucket_dr      = "${local.config.project_name}-terraform-state-${local.config.dr_region}"
}