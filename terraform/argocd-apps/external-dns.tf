locals {
  external_dns_defaults = {
    external-dns = merge({
      enabled          = var.enable_external_dns
      argo_app_repo    = var.global_git_repo
      namespace        = "external-dns"
      name             = "external-dns"
      source_helm_repo = "https://charts.bitnami.com/bitnami"
      target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
      chart_version    = "6.5.5"
      argo_auto_sync   = true
    }, var.external_dns_context)
  }

  external_dns_values = var.enable_external_dns ? {
    external-dns = {
      path_prefix     = local.local_charts_values_filename_prefix
      override_values = var.external_dns_values
      data = {
        serviceAccount = {
          annotations = {
            name                         = "external-dns"
            "eks.amazonaws.com/role-arn" = module.external_dns_irsa.0.irsa_iam_role_arn
          }
        }
        LogLevel   = "info"
        provider   = "aws"
        registry   = "txt"
        txtOwnerId = data.terraform_remote_state.eks.outputs.eks.cluster_name
        txtPrefix  = "external-dns"
        policy     = "sync"
        sources = [
          "service",
          "ingress"
        ]
        domainFilters = [
          var.cluster_domain
        ]
        publishInternalServices = true
        triggerLoopOnEvent      = true
        interval                = "5m"
      }
    }
  } : null
}

data "aws_iam_policy_document" "external_dns_iam_policy_document" {
  count = var.enable_external_dns  ? 1 : 0
  statement {
    effect    = "Allow"
    resources = [data.aws_route53_zone.this.arn]
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "route53:ListHostedZones"
    ]
  }
}

resource "aws_iam_policy" "external_dns" {
  count       = var.enable_external_dns ? 1 : 0
  description = "External DNS IAM policy."
  name        = "${local.oidc_context.eks_cluster_id}-external-dns-irsa"
  policy      = data.aws_iam_policy_document.external_dns_iam_policy_document.0.json
}

module "external_dns_irsa" {
  count                             = var.enable_external_dns ? 1 : 0
  source                            = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.0.4"
  addon_context                     = local.oidc_context
  kubernetes_service_account        = "external-dns"
  kubernetes_namespace              = "external-dns"
  create_kubernetes_namespace       = false
  create_kubernetes_service_account = false
  irsa_iam_policies                 = [aws_iam_policy.external_dns.0.arn]
}

