data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "guru-nuvalence-state"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.aws_eks_cluster.this.name
}