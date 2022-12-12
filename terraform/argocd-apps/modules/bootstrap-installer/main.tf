locals {
  utility_script_filepath = "${var.dest_path}/scripts/bootstrap-utility.sh"
}

# this file can be templated, but it cannot contain any non-template-var ${ } phrases
resource "local_file" "installer-wrapper" {
  filename        = "${var.dest_path}/bootstrap-eks.sh"
  file_permission = "0755"
  content = templatefile("${path.module}/templates/installer-wrapper.tpl.sh", {
    customer_name           = var.customer_name
    aws_region              = var.aws_region
    eks_cluster_name        = var.eks_cluster_name
    namespaces              = local.namespaces
    charts                  = local.charts
    chart_values_files      = local.chart_values_files
    charts_to_install       = var.charts_to_install
    manifests               = local.manifests
    chart_cleanup_resources = local.chart_cleanup_resource_list

    debug                   = var.debug
    verbose                 = var.verbose
    utility_script_filepath = trimprefix(var.dest_path, local.utility_script_filepath)
  })
}

# this file cannot be templated as Terraform stupidly chose ${ } for its interpolation markup.
resource "local_file" "installer-actual" {
  filename        = local.utility_script_filepath
  file_permission = "0755"
  content         = file("${path.module}/templates/bootstrap-utility.sh")
}