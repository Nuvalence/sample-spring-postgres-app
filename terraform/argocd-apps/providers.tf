provider "aws" {
  region = var.aws_region
}

provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.eks.cluster_endpoint
  cluster_ca_certificate = data.aws_eks_cluster.this.certificate_authority
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}