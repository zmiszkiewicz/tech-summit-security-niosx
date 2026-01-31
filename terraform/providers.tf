# Terraform provider configuration - AWS only
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.20.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
