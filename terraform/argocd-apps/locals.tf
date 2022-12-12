
locals {
  cluster_name          = data.terraform_remote_state.eks.outputs.eks.cluster_name
  cluster_domain        = data.terraform_remote_state.eks.outputs.cluster_domain
  chart_values_path_app = var.values_with_charts ? "./" : var.chart_values_directory != "" ? var.chart_values_directory : "../../chart-values"

  apps_path          = join("/", compact([var.repo_root_directory, var.app_directory_path, var.apps_by_workspace ? terraform.workspace : ""]))
  charts_path        = join("/", compact([var.repo_root_directory, var.charts_directory, var.apps_by_workspace ? terraform.workspace : ""]))
  charts_values_path = var.values_with_charts ? local.charts_path : join("/", compact([var.repo_root_directory, var.chart_values_directory, var.apps_by_workspace ? terraform.workspace : ""]))
  manifests_path     = join("/", compact([var.repo_root_directory, "manifests", var.apps_by_workspace ? terraform.workspace : ""]))

  local_charts_filename_prefix        = join("/", compact([var.local_directory_path, local.charts_path]))
  local_apps_filename_prefix          = join("/", compact([var.local_directory_path, local.apps_path]))
  local_charts_values_filename_prefix = join("/", compact([var.local_directory_path, local.charts_values_path]))
  local_manifests_filename_prefix     = join("/", compact([var.local_directory_path, local.manifests_path]))

  ingress_nginx_public_subnets = data.terraform_remote_state.eks.outputs.public_subnets
  vpc_id                       = var.vpc_id != "" ? var.vpc_id : data.terraform_remote_state.eks.outputs.vpc_id
  acm_arn                      = var.ingress_nginx_acm_certificate_arn != "" ? var.ingress_nginx_acm_certificate_arn : data.terraform_remote_state.eks.outputs.acm_arn

  oidc_context = {
    aws_caller_identity_account_id = data.aws_caller_identity.current.account_id
    aws_caller_identity_arn        = data.aws_caller_identity.current.arn
    aws_eks_cluster_endpoint       = data.aws_eks_cluster.this.endpoint
    aws_partition_id               = data.aws_partition.current.id
    aws_region_name                = var.aws_region
    eks_cluster_id                 = data.aws_eks_cluster.this.id
    eks_oidc_issuer_url            = data.terraform_remote_state.eks.outputs.eks.cluster_oidc_issuer_url
    eks_oidc_provider_arn          = data.terraform_remote_state.eks.outputs.eks.oidc_provider_arn
    tags = {
      env = terraform.workspace
    }
  }

  defaults = merge(
    local.aws_lb_controller_defaults,
    local.aws_ebs_csi_driver_defaults,
    local.external_dns_defaults,
    {
      "${local.cluster_name}-apps" = {
        enabled        = var.create_bootstrap_app_of_apps
        argo_app_repo  = var.global_git_repo
        app_name       = "${local.cluster_name}-apps"
        argo_namespace = "argocd"
        app_namespace  = "argocd"
        namespace      = "argocd"
        filename       = join("/", [local.local_apps_filename_prefix, "${local.cluster_name}-app-of-apps.yaml"])
        name           = "${local.cluster_name}-app-of-apps"
        path           = local.apps_path
        target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
        is_helm_chart  = false
        values_files_path_prefix = ""
        values_defaults_filename = ""
        values_overrides_filename = ""
        automated_update = true
        argo_auto_sync = true
        recurse_dir    = true
      }
    },
    {
      argo-cd = merge({
        enabled          = var.enable_argocd
        argo_app_repo    = var.global_git_repo
        namespace        = "argocd"
        name             = "argo-cd"
        source_helm_repo = "https://argoproj.github.io/argo-helm"
        chart_version    = "4.9.4"
        argo_auto_sync   = true
        target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
        recurse_dir      = false
    }, var.argocd_context) },
    {
      ingress-nginx = merge({
        enabled          = var.enable_ingress_nginx
        argo_app_repo    = var.global_git_repo
        namespace        = "nginx-ingress-system"
        name             = "ingress-nginx"
        source_helm_repo = "https://kubernetes.github.io/ingress-nginx"
        target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
        chart_version    = "4.1.4"
        argo_auto_sync   = true
    }, var.ingress_nginx_context) },
    {
      cert-manager = merge({
        enabled          = var.enable_cert_manager
        argo_app_repo    = var.global_git_repo
        name             = "cert-manager"
        namespace        = "cert-manager"
        source_helm_repo = "https://charts.jetstack.io"
        chart_version    = "v1.7.1"
        target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
        argo_auto_sync   = true
      }, var.cert_manager_context)
    },
    {
      rustrial-aws-eks-iam-auth-controller = merge({
        enabled          = var.enable_iam_auth_controller
        argo_app_repo    = var.global_git_repo
        namespace        = "kube-system"
        name             = "rustrial-aws-eks-iam-auth-controller"
        source_helm_repo = "https://rustrial.github.io/aws-eks-iam-auth-controller"
        chart_version    = "0.1.7"
        target_revision = terraform.workspace == "prod" ? "main" : terraform.workspace
        argo_auto_sync   = true
      }, var.iam_auth_controller_context)
    }
  )

  argo_dex_config = var.enable_argocd_oauth ? ({
    "dex.config" = <<EOF
connectors:
- config:
    issuer: https://accounts.google.com
    clientID: ${var.argocd_oauth_client_id}
    clientSecret: ${"$"}${var.argocd_oidc_auth_secret_name}:client_secret
  type: oidc
  id: google
  name: Google
EOF
  }) : {}

  chart_values = merge(
    local.aws_lb_controller_values,
    local.aws_ebs_csi_driver_values,
    local.external_dns_values,
    var.enable_ingress_nginx ?
    {
      ingress-nginx = {
        override_values = var.ingress_nginx_values
        path_prefix     = local.local_charts_values_filename_prefix
        data = {
          controller = {
            service = {
              loadBalancerSourceRanges = length(var.nginx_load_balancer_source_ranges) > 0 ? var.nginx_load_balancer_source_ranges : null
              annotations = merge({
                "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "ssl"
                "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout"           = "60"
                "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
                "service.beta.kubernetes.io/aws-load-balancer-internal"                          = "false"
                "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
                "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
                "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "instance"
                "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"              = "TCP"
                "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"                  = "443"
                "service.beta.kubernetes.io/aws-load-balancer-subnets"                           = trimsuffix(join(",", local.ingress_nginx_public_subnets), ",")
                "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy"            = "ELBSecurityPolicy-TLS13-1-2-2021-06"
                },
                length(var.ingress_nginx_hostnames) > 0 ? {
                  "dns.alpha.kubernetes.io/hostname" = join(",", var.ingress_nginx_hostnames)
                } : {},
                var.ingress_nginx_acm_certificate_arn != "" ? {
                  "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = local.acm_arn
                } : {}
              )
            }
          }
        }
      }
    } : null,

    var.enable_cert_manager ? {
      cert-manager = {
        override_values = var.cert_manager_values
        path_prefix     = local.local_charts_values_filename_prefix
        data = {
          installCRDs = true
        }
      }
    } : {},

    var.enable_argocd ? {
      argo-cd = {
        override_values = var.argocd_values
        path_prefix     = local.local_charts_values_filename_prefix
        data = {
          server = {
            config = merge({
              url = "https://argocd.${local.cluster_domain}"
            }, local.argo_dex_config)
            rbacConfig = (var.enable_argocd_oauth ? {
              "policy.default" = "role:readonly"
              "policy.csv"     = <<EOF
p, role:org_admin, *, *, *, allow
g, eng_infra@ironnetcybersecurity.com, role:admin
%{for p in var.argocd_policies}
${p}
%{endfor}
EOF
            } : {})
            extraArgs = ["--insecure"]
            ingress = {
              enabled = true
              annotations = {
                "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
                "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
              }
              ingressClassName = "nginx"
              hosts            = ["argocd.${var.cluster_domain}"]
              https            = false
              tls = [
                {
                  hosts      = ["argocd.${var.cluster_domain}"]
                  secretName = "argocd-secret"
                }
              ]
            }
            ingressGrpc = {
              enabled = true
              annotations = {
                "nginx.ingress.kubernetes.io/backend-protocol" = "GRPC"
              }
              ingressClassName = "nginx"
              hosts            = ["argo-grpc.${var.cluster_domain}"]
              https            = true
              tls = [
                {
                  hosts      = ["argo-grpc.${var.cluster_domain}"]
                  secretName = "argocd-secret"
                }
              ]
            }
            additionalApplications = [
              {
                name = "bootstrap"
                finalizers = [
                  "resources-finalizer.argocd.argoproj.io"
                ]
                project = "default"
                source = {
                  repoURL        = var.global_git_repo
                  targetRevision = "HEAD"
                  path           = local.apps_path
                }
                destination = {
                  server    = "https://kubernetes.default.svc"
                  namespace = "argocd"
                }
                syncPolicy = {
                  automated = {
                    prune    = true
                    selfHeal = false
                  }
                  syncOptions = [
                    "CreateNamespace=true",
                    "ApplyOutOfSyncOnly=true"
                  ]
                }
              }
            ]
          }
        }
      }
    } : null,
    {
      rustrial-aws-eks-iam-auth-controller = {
        path_prefix = local.local_charts_values_filename_prefix
        data        = var.iam_auth_controller_values
      }

    },
  )

  enabled_charts = {
    for chart, config in local.enabled_apps :
    chart => merge(config, { filename = join("/", [local.local_charts_filename_prefix, chart, "Chart.yaml"]) })
    if lookup(config, "is_helm_chart", true)
  }

  enabled_apps = {
    for app, config in local.defaults :
    app => merge({
      argo_app_repo           = config.argo_app_repo
      filename                = lookup(config, "filename", "${local.local_apps_filename_prefix}/${app}.yaml")
      name                    = app
      directory               = lookup(config, "is_helm_chart", true) ? "${local.charts_path}/${app}" : ""
      is_helm_chart           = lookup(config, "is_helm_chart", true)
      chart_version           = lookup(config, "is_helm_chart", true) ? config.chart_version : ""
      source_helm_repo        = lookup(config, "is_helm_chart", true) ? config.source_helm_repo : ""
      namespace               = config.namespace
      auto_update             = lookup(config, "argo_auto_sync", true)
      recurse_dir             = lookup(config, "recurse_dir", false)
      additional_sync_options = lookup(config, "additional_sync_options", null)
    }, config)
    if config.enabled
  }

  manifest_apps = {
    for app_name, app in var.additional_manifest_apps : app_name => merge(
      app, {
        path = lookup(app, "manifests_dir", "") != "" ? "${local.manifests_path}/${app.manifests_dir}" : "${local.manifests_path}/${app_name}"
      }
    ) if lookup(app, "argo_app_repo", null) != null
  }
}