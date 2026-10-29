terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Remote state with locking. Create the bucket and table once, then
  # uncomment and run `terraform init -migrate-state`.
  # backend "s3" {
  #   bucket         = "my-tfstate-bucket"
  #   key            = "cicd-observability/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
