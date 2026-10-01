terraform {
  required_version = ">= 1.6"

  cloud {
    organization = "gsouto-labs"

    workspaces {
      name = "ml-platform-aws"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "gs-${var.environment}-ml-platform"

  common_tags = {
    project       = "ml-platform-aws"
    env           = var.environment
    managed_by    = "terraform"
    instance_name = "ml-platform-aws",
    repo          = "github.com/soutogustavo/ml-platform-aws"
  }
}
