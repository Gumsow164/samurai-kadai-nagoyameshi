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
    bucket  = "nagoyameshi-prod-tfstate-0929-gotou"
    key     = "nagoyameshi-prod-tfstate.tfstate"
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

#----------------------------------------------------------
# outputs
#----------------------------------------------------------
output "db_password" {
  value     = random_string.db_password.result
  sensitive = true
}

output "db_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}