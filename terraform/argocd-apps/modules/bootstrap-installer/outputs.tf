output "namespaces" {
  value       = local.namespaces
  description = "List of namespaces created by installer.  \"default\" will never be in this list."
}

output "charts" {
  value       = local.charts
  description = "List of chart names and namespaces installed by the installer."
}

output "manifests" {
  value       = local.manifests
  description = "List of manifest names and namespaces applied by the installer"
}