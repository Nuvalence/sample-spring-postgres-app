output "rendered_charts" {
  value       = local_file.helm_charts
  description = "Any / all rendered Helm chart files"
}

output "rendered_argo_apps" {
  value       = local_file.argo_apps
  description = "Any / all rendered Argo app files"
}

output "rendered_chart_values" {
  value       = local_file.chart_values
  description = "Any / all rendered Helm chart values.yaml files"
}

output "rendered_manifests" {
  value       = local_file.manifests
  description = "Any / all rendered Kubernetes custom resource manifest files"
}

output "charts" {
  description = "Provided chart definitions"
  value = {
    for chart_name, chart in local.charts : chart_name => merge(
      chart,
      {
        directory = trimsuffix(chart.filename, "/Chart.yaml")
      }
    )
  }
}

output "argo_apps" {
  description = "Provided Argo app definitions"
  value       = local.argo_apps
}

output "chart_values" {
  description = "Provided chart value file definitions"
  value       = local.chart_values
}

output "manifests" {
  description = "Provided manifest definitions"
  value       = local.manifests
}