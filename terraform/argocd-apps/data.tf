data "terraform_remote_state" "eks" {
  backend = "s3"
  workspace = terraform.workspace
  config = {
    region         = var.aws_region
    bucket         = "nuvalence-eks-state"
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.aws_eks_cluster.this.name
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_route53_zone" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_domain
}