# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER FOR TF CLOUD
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket         = "tdsterraformstatefile"  
    key            = "tdsterraformstatefile/statefile/terraform.tfstate"    
    region         = "us-east-1"                    
    encrypt        = true                           
    dynamodb_table = "terraform-lock-table"         
  }
}

provider "aws" {
  region  = "us-east-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS PROVIDER USING TF CLI
# ---------------------------------------------------------------------------------------------------------------------

# provider "aws" {
#   profile = "default-ecs"
#   version = "~> 2.25"
#   region  = "${var.aws_region}"
# }

# terraform {
#   required_version = "~>0.12"
#   backend "remote" {
#     organization = "aws-isv"

#     workspaces {
#       name = "petclinic-fargate"
#     }
#   }
# }
