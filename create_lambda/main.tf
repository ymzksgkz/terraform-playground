terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.66.0"
    }
  }
  required_version = ">=1.9.5"
  backend "s3" {
    key             = "terraform/state.tfstate"
    encrypt         = true
    lock_table      = true
  }
}

provider "aws" {
  region = var.region
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs
resource "aws_s3_bucket" "test_bucket" {
  bucket        = "test-bucket-${var.project_id}"
  force_destroy = true
  tags          = var.common_tags
}
