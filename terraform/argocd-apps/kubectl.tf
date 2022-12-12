resource "kubectl_manifest" "app_of_apps" {
  yaml_body = file(join("/", [local.local_apps_filename_prefix, "${local.cluster_name}-app-of-apps.yaml"]))
}