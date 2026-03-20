provider "aws" {
  region = local.config.primary_region
}

provider "aws" {
  region = local.config.primary_region
  alias  = "primary"
}

provider "aws" {
  region = local.config.dr_region
  alias  = "dr"
}

terraform {
  # IMPORTANT: Comment out this 'backend' block the FIRST time you run terraform apply.
  # After creating the bucket and table, uncomment and run 'terraform init' to migrate 
  # the state.

# backend "s3" {
#     bucket         = "pilot-light-dr-salvador-terraform-state-us-east-1"
#     key            = "dr-test/terraform.tfstate"
#     region         = "us-east-1" 
#     encrypt        = true
#     dynamodb_table = "terraform-lock-table"
#   }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}