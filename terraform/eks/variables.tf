
variable "aws_region" {
  default = "us-east-1"
  description = "AWS REgion for EKS cluster"
}

variable "cluster_name" {
  description = "EKS Cluster Name. Concatenated with terraform.workspace"
  type = string
}