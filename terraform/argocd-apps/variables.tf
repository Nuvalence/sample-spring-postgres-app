######################################################
##                 Generic Config                   ##
######################################################
variable "test_mode" {
  type        = bool
  default     = false
  description = "Enable to skip AWS Resource Creation and provide dummy values for the context"
}

variable "vpc_id" {
  default     = ""
  description = "VPC ID where the eks cluster is deployed"
  type        = string
}

variable "cluster_name" {
  default     = ""
  description = "The EKS cluster name for alb controller"
  type        = string
}

variable "aws_region" {
  default = "us-east-1"
  type    = string
}


variable "global_git_repo" {
  default     = ""
  description = "The config repo to point apps to when app_repo is not set in its context"
  type        = string
}

variable "tags" {
  default     = {}
  type        = map(string)
  description = "Tags to apply to resources"
}

variable "additional_installer_charts" {
  default     = {}
  description = "Additional Helm charts to add to installer. For use when the chart/app is not managed by this module"
}

variable "values_with_charts" {
  default     = true
  description = "Store values files with helm chart"
}

variable "additional_bootstrap_helm_apps" {
  default     = {}
  description = <<EOF
List of additional helm addon contexts to generate argo applications for
```
additional_bootstrap_helm_apps =
  awx-operator = {
      enabled        = true
      namespace      = "aws"
      helm_repo      = "https://ansible.github.io/awx-operator/"
      chart_version  = "0.28.0"
      values         = {
        AWX = {
          enabled = true
          name    = awx
        }
      }
      argo_auto_sync = true
  }
```
EOF
}

variable "additional_bootstrap_helm_values" {
  default     = {}
  description = <<EOF
List of additional helm addon contexts to generate argo applications for
```
additional_bootstrap_helm_apps =
  awx-operator = {
      AWX:
        spec:
          hostname: awx.example.com
  }
```
EOF
}

variable "manifests" {
  default     = []
  description = <<EOD
List of maps of Kubernetes custom resource manifest files to generate.

The value must be an object as described below:

```
  type = list(object({
    filename = optional(string)

    api_version = string
    kind = string
    name = string
    namespace = optional(string)
    labels = optional(map(map(string))
    annotations = optional(map(map(string))
    spec = {{ any }}
  }))
```

We cannot define a strict type on this variable directly due to Terraform type conversion constraints.

module "mymanifests" {
  source "./modules/file-generator"

  manifests = [
    {
      name = "my-great-resource"
      api_version = "fqn.domain.tld/v1"
      kind = "ResourceKind"
      spec = {
        keyOne = "value one"
        keyTwo = {
          subKey = "subValue"
        }
      }
    }
  ]
}

EOD
}

variable "additional_manifest_apps" {
  default     = {}
  type        = map(any)
  description = <<EOF
Additional map of manifest oriented apps to be created.
Manifests must be submitted manually, through PR requests to the config repository.

```
additional_manifest_apps = {
  manifest_apps = {
    bootstrap-resources = {
      target_revision = "HEAD"
      auto_update     = true
      recurse_dir     = true
      path            = "bootstrap/resources"
    }
  }
}
```

EOF
}

variable "gitops_pre_argo_charts" {
  type = list(string)
  default = [
    "aws-ebs-csi-driver",
    "external-dns",
    "ingress-nginx",
    "aws-load-balancer-controller",
    "cert-manager",
    "argo-cd"
  ]
  description = <<EOD
When `manage_via_gitops` is enabled, these are the charts that will be manually installed by the installer script prior
to ArgoCD taking over.

NOTE: `argo-cd` _must_ be in this list, and it more than likely should be the last item in the list.

This var does nothing when `manage_via_gitops` is false.
EOD
}

variable "additional_kubernetes_namespaces" {
  type        = list(string)
  default     = []
  description = <<EOD
List of Kubernetes namespaces to be created by the installer script prior to installing any charts.  The order is
irrelevant.
NOTE: If a deployed chart's configuration contains a `namespace` directive, it will be automatically created by the
script, so it does not need to be here.
This is _only_ for _additional_ namespaces not already present in a chart.
EOD
}

variable "additional_charts_for_bootstrap" {
  default     = {}
  description = "charts output from file-generator module"
}

######################################################
##             File Generator Config                ##
######################################################
variable "create_bootstrap_app_of_apps" {
  default = false
  description = "Generate an app of apps for the TF Workspace Argo Deployment"
  type = bool
}

variable "repo_root_directory" {
  default     = ""
  type        = string
  description = "Root repository directory where files are referenced from argo"
}

variable "local_directory_path" {
  default     = "../.."
  description = "Local directory path to write files to."
}

variable "apps_by_workspace" {
  default     = false
  description = "Organize Directories by TF workspace deployments"
  type        = bool
}

variable "app_directory_path" {
  default     = "apps"
  description = "Path where Argo Application manifest files/directories should be stored, relative to var.root_directory"
  type        = string
}

variable "charts_directory" {
  default     = "charts"
  description = "Path where Charts files/directories should be stored, relative to var.root_directory"
  type        = string
}

variable "chart_values_directory" {
  default     = "charts-values"
  type        = string
  description = "Directory Path where chart values should be written to, will default to Chart path. Relative to var.root_directory"
}



######################################################
##                  ArgoCD Config                   ##
######################################################
variable "enable_argocd" {
  default     = true
  description = "Enable or Disable ArgoCD"
}
variable "argocd_context" {
  default     = {}
  description = "Ingress Nginx Helm Chart context"
}

variable "argocd_values" {
  default     = {}
  description = "ArgoCD Chart Values"
}

variable "argocd_oidc_auth_secret_name" {
  default     = "argocd-oauth"
  description = "Kubernetes secret name for ArgoCD OIDC Connectio credentials."
}

variable "argocd_policies" {
  type        = list(string)
  default     = []
  description = "List of additional argocd rbac policies for oauth"
}

variable "argocd_oauth_client_id" {
  default     = ""
  description = "Google Oauth Client ID generated for connection to google APIs."
}

variable "enable_argocd_oauth" {
  default     = false
  description = "Enable/Disable Oauth connection for argocd frontend."
}
######################################################
##             Ingress Nginx Config                 ##
######################################################
variable "enable_ingress_nginx" {
  default     = true
  description = "Enable/Disable Ingress Nginx"
}

variable "ingress_nginx_context" {
  default     = {}
  description = "Ingress Nginx Helm Chart context"
}

variable "ingress_nginx_values" {
  default     = {}
  description = "Ingress Nginx Helm Chart context"
}

variable "ingress_nginx_hostnames" {
  default     = []
  description = "Optional list of hostnames to be associated to the ingress nginx LB"
}
variable "nginx_load_balancer_source_ranges" {
  default     = []
  description = "Additional Cidr's to append to the source ranges allowed to access the Ingress Nginx LB"
}

variable "ingress_nginx_acm_certificate_arn" {
  default     = ""
  description = "ACM Certificate for NLB to do TLS termination"
  type        = string
}
variable "ingress_nginx_public_subnets" {
  default     = []
  description = "List of public subnets for Ingress Nginx LB"
  type        = list(string)
}

######################################################
##             External DNS Config                  ##
######################################################
variable "enable_external_dns" {
  default     = true
  description = "Enable/Disable External DNS"
}

variable "cluster_domain" {
  default     = ""
  description = "Cluster Domain for external DNS to monitor"
  type        = string
}

variable "aws_route53_zone_arn" {
  default     = ""
  description = "Route 53 ARN for external dns config"
  type        = string
}

variable "external_dns_context" {
  default     = {}
  description = "External DNS Helm Chart context"
}


variable "external_dns_values" {
  default     = {}
  description = "External DNS Chart Values"
}

######################################################
##             Cert Manager Config                  ##
######################################################
variable "enable_cert_manager" {
  default     = true
  description = "Enable/Disable Cert Manager"
}

variable "cert_manager_context" {
  default     = {}
  description = "Cert Manager Helm Chart context"
}

variable "cert_manager_values" {
  default     = {}
  description = "Cert Manager Chart Values"
}

######################################################
##           Cluster Autoscaler Config              ##
######################################################
variable "enable_cluster_autoscaler" {
  default     = false
  description = "Enable/Disable Cluster AutoScaler"
}

variable "cluster_autoscaler_context" {
  default     = {}
  description = "Cluster Autoscaler Helm Chart context"
}

variable "cluster_autoscaler_values" {
  default     = {}
  description = "Cluster Autoscaler Chart Values"
}

######################################################
##                   Keda Config                    ##
######################################################
variable "enable_keda" {
  default     = true
  description = "Enable/Disable Keda"
}

variable "keda_context" {
  default     = {}
  description = "Keda Helm Chart context"
}

variable "keda_values" {
  default     = {}
  description = "Keda Helm chart Values"
}

######################################################
##           IAM Auth Controller Config             ##
######################################################
variable "enable_iam_auth_controller" {
  default     = true
  description = "Enable/Disable Cert Manager"
}

variable "iam_auth_controller_context" {
  default     = {}
  description = "IAM Auth Controller Context"
}

variable "iam_auth_controller_values" {
  default     = {}
  description = "IAM Auth Controller Chart Values"
}

######################################################
##           AWS LB Controller Config               ##
######################################################
variable "enable_aws_lb_controller" {
  default     = true
  description = "Enable/Disable AWS LB Controller"
}

variable "aws_lb_controller_context" {
  default     = {}
  description = "AWS EBS CSI Driver Context"
}

variable "aws_load_balancer_controller_values" {
  default     = {}
  description = "AWS LB Controller Chart Values"
}

######################################################
##           AWS EBS CSI Driver Config              ##
######################################################
variable "enable_aws_ebs_csi_driver" {
  default     = true
  description = "Enable/Disable AWS EBS CSI Driver"
}

variable "aws_ebs_csi_driver_context" {
  default     = {}
  description = "AWS EBS CSI Driver Context"
}

variable "aws_ebs_csi_driver_values" {
  default     = {}
  description = "AWS EBS Chart Values"
}

