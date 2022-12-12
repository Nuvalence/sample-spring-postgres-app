module "file-gen" {
  source = "./modules/terraform-file-generator"

  repo_root_directory  = var.repo_root_directory
  local_directory_path = var.local_directory_path
  charts               = merge(local.enabled_charts, var.additional_bootstrap_helm_apps)
  values_with_charts   = true

  argo_apps = {
    for app_name, app in merge(local.enabled_apps, var.additional_bootstrap_helm_apps, local.manifest_apps) : app_name => merge(
      app, (
        try(app.is_helm_chart, true)
        ? { values_file_path_prefix = "${local.chart_values_path_app}/${app_name}" }
        : { values_file_path_prefix = null }
      ),
    ) if lookup(app, "argo_app_repo", null) != null && app_name != "castai-evictor"
  }
  chart_values = merge(local.chart_values, var.additional_bootstrap_helm_values)

  manifests = length(var.manifests) > 0 ? var.manifests : []
}