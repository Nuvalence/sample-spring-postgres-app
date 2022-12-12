# Terraform - Kubernetes Bootstrap Apps

Terraform module to generate Argo-CD Applications to bootstrap an eks cluster

<!-- BEGINNING OF TERRAFORM-DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=4.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.29.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_atlantis_irsa"></a> [atlantis\_irsa](#module\_atlantis\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |
| <a name="module_aws_ebs_csi_driver_controller_irsa"></a> [aws\_ebs\_csi\_driver\_controller\_irsa](#module\_aws\_ebs\_csi\_driver\_controller\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |
| <a name="module_aws_ebs_csi_driver_node_irsa"></a> [aws\_ebs\_csi\_driver\_node\_irsa](#module\_aws\_ebs\_csi\_driver\_node\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |
| <a name="module_aws_lb_controller_irsa"></a> [aws\_lb\_controller\_irsa](#module\_aws\_lb\_controller\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.7.0 |
| <a name="module_bootstrap_apps"></a> [bootstrap\_apps](#module\_bootstrap\_apps) | /Users/dustin.hendel/projects/terraform-file-generator | n/a |
| <a name="module_cluster_autoscaler_irsa"></a> [cluster\_autoscaler\_irsa](#module\_cluster\_autoscaler\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |
| <a name="module_external_dns_irsa"></a> [external\_dns\_irsa](#module\_external\_dns\_irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |
| <a name="module_keda-irsa"></a> [keda-irsa](#module\_keda-irsa) | github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa | v4.0.4 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.atlantis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.aws_ebs_csi_driver_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.external_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.keda_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_document.atlantis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_ebs_csi_driver_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.external_dns_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.keda_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The EKS cluster name for alb controller | `any` | n/a | yes |
| <a name="input_eks_cluster_id"></a> [eks\_cluster\_id](#input\_eks\_cluster\_id) | The cluster id from the cluster | `string` | n/a | yes |
| <a name="input_manage_via_gitops"></a> [manage\_via\_gitops](#input\_manage\_via\_gitops) | If true, will generate argo-cd Helm chart | `bool` | n/a | yes |
| <a name="input_oidc_context"></a> [oidc\_context](#input\_oidc\_context) | OIDC Context for IRSA Role configuration | <pre>object({<br>    aws_caller_identity_account_id = string<br>    aws_caller_identity_arn        = string<br>    aws_eks_cluster_endpoint       = string<br>    aws_partition_id               = string<br>    aws_region_name                = string<br>    eks_cluster_id                 = string<br>    eks_oidc_issuer_url            = string<br>    eks_oidc_provider_arn          = string<br>    tags                           = map(string)<br>    irsa_iam_role_path             = optional(string)<br>    irsa_iam_permissions_boundary  = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_root_directory"></a> [root\_directory](#input\_root\_directory) | Root directory where files/directories will be written | `string` | n/a | yes |
| <a name="input_additional_bootstrap_helm_apps"></a> [additional\_bootstrap\_helm\_apps](#input\_additional\_bootstrap\_helm\_apps) | List of additional helm addon contexts to generate argo applications for<pre>additional_bootstrap_helm_apps = [<br>  {<br>      enabled        = true<br>      namespace      = "aws"<br>      name           = "awx-operator"<br>      helm_repo      = "https://ansible.github.io/awx-operator/"<br>      chart_version  = "0.28.0"<br>      values         = {<br>        AWX = {<br>          enabled = true<br>          name    = awx<br>        }<br>      }<br>      argo_auto_sync = true<br>  }<br>]</pre> | <pre>list(object({<br>    enabled        = optional(bool)<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  }))</pre> | `[]` | no |
| <a name="input_additional_manifest_apps"></a> [additional\_manifest\_apps](#input\_additional\_manifest\_apps) | Additional map of manifest oriented apps to be created.<br>Manifests must be submitted manually, through PR requests to the config repository.<pre>additional_manifest_apps = {<br>  bootstrap-resources = {<br>    target_revision = "HEAD"<br>    auto_update     = true<br>    recurse_dir     = true<br>    # Path relative to the root of the repository<br>    path            = "manifests/resources"<br>  }<br>}</pre> | `map(any)` | `{}` | no |
| <a name="input_app_directory_path"></a> [app\_directory\_path](#input\_app\_directory\_path) | Path where Argo Application manifest files/directories should be stored, relative to var.root\_directory | `string` | `""` | no |
| <a name="input_argocd_context"></a> [argocd\_context](#input\_argocd\_context) | Ingress Nginx Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "argo-cd"<br>}</pre> | no |
| <a name="input_atlantis_context"></a> [atlantis\_context](#input\_atlantis\_context) | IAM Auth Controller Context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "name": "atlantis"<br>}</pre> | no |
| <a name="input_aws_ebs_csi_driver_context"></a> [aws\_ebs\_csi\_driver\_context](#input\_aws\_ebs\_csi\_driver\_context) | IAM Auth Controller Context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "aws-ebs-csi-driver"<br>}</pre> | no |
| <a name="input_aws_lb_controller_context"></a> [aws\_lb\_controller\_context](#input\_aws\_lb\_controller\_context) | IAM Auth Controller Context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "aws-load-balancer-controller"<br>}</pre> | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | `"us-east-1"` | no |
| <a name="input_aws_route53_zone_arn"></a> [aws\_route53\_zone\_arn](#input\_aws\_route53\_zone\_arn) | Route 53 ARN for external dns config | `string` | `""` | no |
| <a name="input_cert_manager_context"></a> [cert\_manager\_context](#input\_cert\_manager\_context) | Cert Manager Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "cert-manager"<br>}</pre> | no |
| <a name="input_chart_values_directory"></a> [chart\_values\_directory](#input\_chart\_values\_directory) | Directory Path where chart values should be written to, will default to Chart path. Relative to var.root\_directory | `string` | `""` | no |
| <a name="input_charts_directory"></a> [charts\_directory](#input\_charts\_directory) | Path where Charts files/directories should be stored, relative to var.root\_directory | `string` | `""` | no |
| <a name="input_cluster_autoscaler_context"></a> [cluster\_autoscaler\_context](#input\_cluster\_autoscaler\_context) | Cluster Autoscaler Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "cluster-autoscaler"<br>}</pre> | no |
| <a name="input_cluster_domain"></a> [cluster\_domain](#input\_cluster\_domain) | Cluster Domain for external DNS to monitor | `string` | `""` | no |
| <a name="input_external_dns_context"></a> [external\_dns\_context](#input\_external\_dns\_context) | External DNS Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "external-dns"<br>}</pre> | no |
| <a name="input_global_git_repo"></a> [global\_git\_repo](#input\_global\_git\_repo) | The config repo to point apps to when app\_repo is not set in its context | `string` | `""` | no |
| <a name="input_iam_auth_controller_context"></a> [iam\_auth\_controller\_context](#input\_iam\_auth\_controller\_context) | IAM Auth Controller Context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "rustrial-aws-eks-iam-auth-controller"<br>}</pre> | no |
| <a name="input_ingress_nginx_context"></a> [ingress\_nginx\_context](#input\_ingress\_nginx\_context) | Ingress Nginx Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "ingress-nginx"<br>}</pre> | no |
| <a name="input_keda_context"></a> [keda\_context](#input\_keda\_context) | Keda Helm Chart context | <pre>object({<br>    enabled        = bool<br>    name           = optional(string)<br>    namespace      = optional(string)<br>    helm_repo      = optional(string)<br>    chart_version  = optional(string)<br>    values         = optional(object({}))<br>    argo_auto_sync = optional(bool)<br>    app_repo       = optional(string)<br>  })</pre> | <pre>{<br>  "enabled": true,<br>  "name": "keda"<br>}</pre> | no |
| <a name="input_test_mode"></a> [test\_mode](#input\_test\_mode) | Enable to skip AWS Resource Creation and provide dummy values for the context | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bootstrap_app_charts"></a> [bootstrap\_app\_charts](#output\_bootstrap\_app\_charts) | List of apps that were bootstrapped by this module |
| <a name="output_generated_files"></a> [generated\_files](#output\_generated\_files) | Files generated within this module |
<!-- END OF TERRAFORM-DOCS HOOK -->