
locals {
  values_defaults_filename  = "0-defaults.yaml"
  values_overrides_filename = "9-overrides.yaml"

  apps_path          = var.repo_root_directory != "" ? "${var.repo_root_directory}/apps" : "apps"
  charts_path        = var.repo_root_directory != "" ? "${var.repo_root_directory}/charts" : "charts"
  charts_values_path = var.repo_root_directory != "" ? "${var.repo_root_directory}/chart-values" : "chart-values"
  manifests_path     = var.repo_root_directory != "" ? "${var.repo_root_directory}/manifests" : "manifests"

  local_charts_filename_prefix        = var.local_directory_path != "" ? "${var.local_directory_path}/${local.charts_path}" : local.charts_path
  local_apps_filename_prefix          = var.local_directory_path != "" ? "${var.local_directory_path}/${local.apps_path}" : local.apps_path
  local_charts_values_filename_prefix = var.local_directory_path != "" ? "${var.local_directory_path}/${local.charts_values_path}" : local.charts_values_path
  local_manifests_filename_prefix     = var.local_directory_path != "" ? "${var.local_directory_path}/${local.manifests_path}" : local.manifests_path

  charts = {
    for chart_name, chart in var.charts : chart_name => {
      filename = coalesce(chart.filename, "${local.local_charts_filename_prefix}/${chart_name}/Chart.yaml")

      name          = chart_name
      chart_version = chart.chart_version
      app_version   = chart.app_version
      type          = coalesce(chart.type, "application")
      description   = coalesce(chart.description, "Wrapper chart for ${chart_name}")
      dependencies = (
        (length(coalesce(chart.dependencies, [])) > 0)
        ? chart.dependencies
        : [
          {
            name       = chart_name
            version    = chart.chart_version
            repository = chart.source_helm_repo
          }
        ]
      )
    }
  }

  argo_apps = {
    for app_name, app in var.argo_apps : app_name => {
      filename = coalesce(app.filename, "${local.local_apps_filename_prefix}/${app_name}.yaml")

      app_name      = app_name
      app_namespace = app.namespace
      argo_app_repo = app.argo_app_repo
      argo_namespace = lookup(app, "argo_namespace", "argocd")

      is_helm_chart           = coalesce(app.is_helm_chart, true)
      additional_sync_options = try(app.additional_sync_options, null)
      # this value must be relative to the argo app file location
      values_files_path_prefix = var.values_with_charts ? "" : coalesce(app.values_file_path_prefix, "../../chart-values/${app_name}")

      values_defaults_filename  = local.values_defaults_filename,
      values_overrides_filename = local.values_overrides_filename
      path                      = coalesce(app.path, "${local.charts_path}/${app_name}")
      target_revision           = coalesce(app.target_revision, "HEAD")
      recurse_dir               = app.recurse_dir != null ? app.recurse_dir : false
      automated_update          = app.auto_update != null ? app.auto_update : true
    }
  }

  chart_values = {
    for chart_name, chart_values in var.chart_values : chart_name => {
      chart_name = chart_name
      path_prefix = trimsuffix(
        lookup(chart_values, "path_prefix", var.values_with_charts ? local.local_charts_filename_prefix : local.local_charts_values_filename_prefix),
        "/"
      )
      values_overrides_filename = local.values_overrides_filename
      content                   = yamlencode({ (chart_name) = chart_values.data })
      override_values           = lookup(chart_values, "override_values", null)
    } if chart_values != null
  }

  manifests = {
    for manifest in var.manifests : manifest.name => {
      filename = lookup(manifest, "filename", "${local.local_manifests_filename_prefix}/${manifest.api_version}/${manifest.kind}/${manifest.name}.yaml")

      name        = manifest.name
      api_version = manifest.api_version
      kind        = manifest.kind
      namespace   = lookup(manifest, "namespace", null)
      labels      = lookup(manifest, "labels", {})
      annotations = lookup(manifest, "annotations", {})

      # have to do this stupid nonsense to format the yaml correctly.
      spec_contents = (trimprefix(indent(2, "\n${yamlencode(manifest.spec)}"), "\n"))
    } if manifest != null
  }
}
