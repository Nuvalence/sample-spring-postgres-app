output "state" {
  value = data.terraform_remote_state.eks
}

output "eks_config" {
  value = data.aws_eks_cluster_auth.this.token
}