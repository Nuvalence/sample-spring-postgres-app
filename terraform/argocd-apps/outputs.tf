output "generated_files" {
  value       = module.file-gen.charts
  description = "Files generated within this module"
  sensitive   = true
}

output "additional" {
  value = var.additional_bootstrap_helm_apps
}

output "bootstrap_app_charts" {
  value       = local.enabled_apps
  description = "List of apps that were bootstrapped by this module"
}

output "manifest_apps" {
  value = local.manifest_apps
}