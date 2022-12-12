resource "kubectl_manifest" "app_of_apps" {
  yaml_body = templatefile("modules/terraform-file-generator/templates/argo-app.yaml", local.enabled_apps["${local.cluster_name}-apps"])
}