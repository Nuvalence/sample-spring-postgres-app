locals {
  aws_ebs_csi_driver_defaults = {
    aws-ebs-csi-driver = merge({
      enabled          = var.enable_aws_ebs_csi_driver
      argo_app_repo    = var.global_git_repo
      namespace        = "kube-system"
      name             = "aws-ebs-csi-driver"
      target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
      source_helm_repo = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
      chart_version    = "2.8.0"
      argo_auto_sync   = true
    }, var.aws_ebs_csi_driver_context)
  }

  aws_ebs_csi_driver_values = var.enable_aws_ebs_csi_driver ? {
    aws-ebs-csi-driver = {
      override_values = var.aws_ebs_csi_driver_values
      path_prefix     = local.local_charts_values_filename_prefix
      data = {
        node = {
          serviceAccount = {
            annotations = {
              name                         = "ebs-csi-node-sa"
              "eks.amazonaws.com/role-arn" = module.aws_ebs_csi_driver_node_irsa.0.irsa_iam_role_arn
            }
          }
        }
        controller = {
          k8sTagClusterId = local.oidc_context.eks_cluster_id
          serviceAccount = {
            annotations = {
              name                         = "ebs-csi-controller-sa"
              "eks.amazonaws.com/role-arn" = module.aws_ebs_csi_driver_controller_irsa.0.irsa_iam_role_arn
            }
          }
        }
        storageClasses = [
          {
            name = "default"
            annotations = {
              "storageclass.kubernetes.io/is-default-class" = "false"
            }
            # defaults to Delete
            reclaimPolicy = "Delete"
            parameters = {
              encrypted  = "true"
              type       = "gp3"
              throughput = "125"
            }
          }
        ]
      }
    }
  } : null
}

data "aws_iam_policy_document" "aws_ebs_csi_driver_irsa" {
  count = var.enable_aws_ebs_csi_driver ? 1 : 0
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
    ]
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*",
      "arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:snapshot/*",
    ]

    actions = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"

      values = [
        "CreateVolume",
        "CreateSnapshot",
      ]
    }
  }

  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*",
      "arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:snapshot/*",
    ]

    actions = ["ec2:DeleteTags"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:CreateVolume"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:volume/*"]
    actions   = ["ec2:DeleteVolume"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:snapshot/*"]
    actions   = ["ec2:DeleteSnapshot"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:${local.oidc_context.aws_caller_identity_account_id}:snapshot/*"]
    actions   = ["ec2:DeleteSnapshot"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "aws_ebs_csi_driver_irsa" {
  count       = var.enable_aws_ebs_csi_driver ? 1 : 0
  description = "AWS EBS CSI IAM role policy for EBS manipulation"
  name        = "${local.oidc_context.eks_cluster_id}-aws-ebs-csi-driver-irsa"
  policy      = data.aws_iam_policy_document.aws_ebs_csi_driver_irsa.0.json
  tags        = local.oidc_context.tags
}

module "aws_ebs_csi_driver_node_irsa" {
  count                             = var.enable_aws_ebs_csi_driver ? 1 : 0
  source                            = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.0.4"
  addon_context                     = local.oidc_context
  kubernetes_namespace              = "kube-system"
  kubernetes_service_account        = "ebs-csi-node-sa"
  create_kubernetes_namespace       = false
  create_kubernetes_service_account = false
  irsa_iam_policies                 = [aws_iam_policy.aws_ebs_csi_driver_irsa.0.arn]
}

module "aws_ebs_csi_driver_controller_irsa" {
  count                             = var.enable_aws_ebs_csi_driver ? 1 : 0
  source                            = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.0.4"
  addon_context                     = local.oidc_context
  kubernetes_namespace              = "kube-system"
  kubernetes_service_account        = "ebs-csi-controller-sa"
  create_kubernetes_namespace       = false
  create_kubernetes_service_account = false
  irsa_iam_policies                 = [aws_iam_policy.aws_ebs_csi_driver_irsa.0.arn]
}