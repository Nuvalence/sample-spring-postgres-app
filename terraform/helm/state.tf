terraform {
  backend "s3" {
    bucket = "guru-nuvalence-helm"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}