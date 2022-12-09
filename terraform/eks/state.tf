terraform {
  backend "s3" {
    bucket = "guru-nuvalence-state"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}