output "eks" {
  value = module.eks
}

output "route53_zone_name" {
  value = module.route53_zone.route53_zone_name[local.cluster_domain]
}

output "route53_zone_id" {
  value = module.route53_zone.route53_zone_zone_id[local.cluster_domain]
}

output "cluster_domain" {
  value = local.cluster_domain
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "acm_arn" {
  value = module.acm.acm_certificate_arn
}