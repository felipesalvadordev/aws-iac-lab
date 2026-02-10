terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.65"
    }
  }

  # backend "s3" {
  #   bucket = "terraform-states-flat"
  #   key    = "terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
  allowed_account_ids = [805714761459]
  default_tags {
    tags = {
      Name  = "CreatedBy"
      Owner = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
  allowed_account_ids = [805714761459]

  default_tags {
    tags = {
      Name  = "CreatedBy"
      Owner = "Terraform"
    }
  }
}
