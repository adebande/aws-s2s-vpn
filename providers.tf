terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.17.1"
    }
  }
  backend "s3" {
    bucket  = "s2s-terraform-backend"
    key     = "terraform.tfstate"
    region  = "eu-west-3"
    encrypt = true
  }
}

provider "aws" {
  region = "eu-west-3"
}