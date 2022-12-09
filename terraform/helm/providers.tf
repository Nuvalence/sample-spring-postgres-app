provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  cluster_ca_certificate = ""
}