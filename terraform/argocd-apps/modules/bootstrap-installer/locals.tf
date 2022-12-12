locals {

  DEFAULT_NAMESPACE            = "default"
  DEFAULT_LIFECYCLE            = "ignore"
  DEFAULT_CLEANUP_FAILURE_MODE = "continue"

  # create unique list of namespaces that aren't "default"
  namespaces = [
    for namespace in distinct(compact(concat(
      tolist(var.additional_namespaces),
      [for chart in var.charts : chart.namespace],
      [for manifest in var.manifests : manifest.namespace]
    ))) : namespace if namespace != null && namespace != local.DEFAULT_NAMESPACE
  ]

  # create concise list of charts to be deployed
  charts = [
    for chart in var.charts : {
      name             = chart.name
      directory        = chart.directory
      namespace        = coalesce(chart.namespace, local.DEFAULT_NAMESPACE)
      lifecycle        = coalesce(chart.lifecycle, local.DEFAULT_LIFECYCLE)
      resource_cleanup = coalesce(chart.resource_cleanup, [])
    }
  ]

  # create usable list of chart values files to reference
  chart_values_files = [
    for cv in var.chart_values_files : cv if cv.chart_name != "" && length(cv.values_files) > 0
  ]

  # compile list of resources to clean up per chart
  chart_cleanup_resource_list = flatten([
    for chart in local.charts : [
      for cleanup_resource in chart.resource_cleanup : {
        chart_name = chart.name

        resource_kind = cleanup_resource.resource_kind
        resource_name = cleanup_resource.resource_name
        failure_mode  = coalesce(cleanup_resource.failure_mode, local.DEFAULT_CLEANUP_FAILURE_MODE)
      }
    ] if length(chart.resource_cleanup) > 0
  ])

  # create concise list of manifests to be applied
  manifests = [
    for manifest in var.manifests : {
      filepath  = manifest.filepath
      namespace = coalesce(manifest.namespace, local.DEFAULT_NAMESPACE)
    }
  ]
}