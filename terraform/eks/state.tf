terraform {
  backend "s3" {
    region = "us-east-1"
    bucket = "nuvalence-eks-state"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}