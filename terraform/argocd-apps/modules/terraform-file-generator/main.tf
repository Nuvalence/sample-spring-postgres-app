resource "local_file" "helm_charts" {
  for_each = local.charts

  filename        = each.value.filename
  file_permission = "0664"
  content         = templatefile("${path.module}/templates/Chart.yaml", each.value)
}

resource "local_file" "argo_apps" {
  for_each = local.argo_apps

  filename        = each.value.filename
  file_permission = "0664"
  content         = templatefile("${path.module}/templates/argo-app.yaml", each.value)
}

resource "local_file" "chart_values" {
  for_each = local.chart_values

  filename        = "${each.value.path_prefix}/${each.value.chart_name}/${local.values_defaults_filename}"
  file_permission = "0664"
  content         = templatefile("${path.module}/templates/values-defaults.yaml", each.value)
}


resource "local_file" "manifests" {
  for_each = local.manifests

  filename        = each.value.filename
  file_permission = "0664"
  content         = templatefile("${path.module}/templates/manifest.yaml", each.value)
}