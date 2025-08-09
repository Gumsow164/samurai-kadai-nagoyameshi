#----------------------------------------------------------
# Terraform configuration
#----------------------------------------------------------
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket  = "nagoyameshi-dev-tfstate-v3-gotou-1192"
    key     = "nagoyameshi-dev-tfstate.tfstate"
    region  = "ap-northeast-1"
    profile = "terraform"
  }
}


#----------------------------------------------------------
# Provider
#----------------------------------------------------------
provider "aws" {
  profile = "terraform"
  region  = "ap-northeast-1"
}

#----------------------------------------------------------
# variables
#----------------------------------------------------------
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}