provider "aws" {
  region = var.aws_region
}

variable "root_domain" {

}
locals {
  cluster_name   = "${terraform.workspace}-${var.cluster_name}"
  cluster_domain = "${local.cluster_name}.${var.root_domain}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"
  cidr    = "10.20.0.0/16"

  private_subnets = [
    "10.20.1.0/24",
    "10.20.3.0/24"

  ]
  public_subnets = [
    "10.20.2.0/24",
    "10.20.4.0/24"
  ]

  azs = ["us-east-1a", "us-east-1b"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

}

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "19.0.4"
  vpc_id                         = module.vpc.vpc_id
  cluster_name                   = local.cluster_name
  cluster_version                = "1.22"
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = [
    "71.203.216.20/32"
  ]
  cluster_addons = {
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      addon_version            = "v1.11.2-eksbuild.1"
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2_x86_64"
      instance_types = ["t2.xlarge"]

      # We are using the IRSA created below for permissions
      # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
      # and then turn this off after the cluster/node group is created. Without this initial policy,
      # the VPC CNI fails to assign IPs and nodes cannot join the cluster
      # See https://github.com/aws/containers-roadmap/issues/1666 for more context
      iam_role_attach_cni_policy = true
      min_size                   = 1
      max_size                   = 2
      desired_size               = 1
    }
  }
}

module "vpc_cni_irsa" {
  source  = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>4.12"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "route53_zone" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "${local.cluster_domain}" = {
      comment = "${local.cluster_domain} zone"
      tags = {
        env = terraform.workspace
      }
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

module "root_zone_ns_records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_name = var.root_domain

  records = [
    {
      name    = local.cluster_name
      type    = "NS"
      ttl     = 3600
      records = module.route53_zone.route53_zone_name_servers[local.cluster_domain]
    }
  ]

  depends_on = [module.route53_zone]
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = local.cluster_domain
  zone_id      = module.route53_zone.route53_zone_zone_id[local.cluster_domain]

  subject_alternative_names = [
    "*.${local.cluster_domain}",
  ]

  wait_for_validation = true
}