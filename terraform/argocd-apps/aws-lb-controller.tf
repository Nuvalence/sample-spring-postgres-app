locals {
  aws_lb_controller_defaults = {
    aws-load-balancer-controller = merge({
      enabled          = var.enable_aws_lb_controller
      argo_app_repo    = var.global_git_repo
      name             = "aws-load-balancer-controller"
      namespace        = "alb-controller-system"
      source_helm_repo = "https://aws.github.io/eks-charts"
      chart_version    = "1.4.2"
      argo_auto_sync   = true
    }, var.aws_lb_controller_context)
  }

  aws_lb_controller_values = var.enable_aws_lb_controller ? {
    aws-load-balancer-controller = {
      override_values = var.aws_load_balancer_controller_values
      path_prefix = local.local_charts_values_filename_prefix
      data = {
        clusterName = local.cluster_name
        region      = var.aws_region
        logLevel    = "debug"
        serviceAccount = {
          annotations = {
            "name"                       = "aws-load-balancer-controller"
            "eks.amazonaws.com/role-arn" = module.aws_lb_controller_irsa.0.irsa_iam_role_arn
          }
        }
      }
    }
  } : null
}

data "aws_iam_policy_document" "aws_lb" {
  count = var.enable_aws_lb_controller ? 1 : 0
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:CreateSecurityGroup"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${local.oidc_context.aws_partition_id}:ec2:*:*:security-group/*"]
    actions   = ["ec2:CreateTags"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${local.oidc_context.aws_partition_id}:ec2:*:*:security-group/*"]

    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/ingress.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:DeleteTargetGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/ingress.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${local.oidc_context.aws_partition_id}:ec2:*:*:security-group/*"]

    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${local.oidc_context.aws_partition_id}:elasticloadbalancing:*:*:targetgroup/*/*"]

    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]
  }
}
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count       = var.enable_aws_lb_controller ? 1 : 0
  name        = "${local.oidc_context.eks_cluster_id}-lb-irsa"
  description = "Allows lb controller to manage ALB and NLB"
  policy      = data.aws_iam_policy_document.aws_lb.0.json
  tags        = local.oidc_context.tags
}


module "aws_lb_controller_irsa" {
  count                             = var.enable_aws_lb_controller ? 1 : 0
  source                            = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.7.0"
  eks_oidc_provider_arn             = local.oidc_context.eks_oidc_provider_arn
  eks_cluster_id                    = local.oidc_context.eks_cluster_id
  kubernetes_service_account        = "aws_load_balancer_controller"
  kubernetes_namespace              = "kube-system"
  create_kubernetes_namespace       = false
  create_kubernetes_service_account = false
  irsa_iam_policies                 = [aws_iam_policy.aws_load_balancer_controller.0.arn]
  irsa_iam_role_name                = "${local.cluster_name}-alb-irsa"
}

