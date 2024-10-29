terraform {
  backend "s3" {
    bucket         = "tdsterraformstatefile"  
    key            = "tdsterraformstatefile/statefile"    
    region         = "us-east-1"                    
    encrypt        = true                           
    dynamodb_table = "terraform-lock-table"         
  }
}