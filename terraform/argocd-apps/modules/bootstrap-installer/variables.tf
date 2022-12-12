variable "customer_name" {
  type = string
}

variable "dest_path" {
  description = "Destination to write the installer script to"
}

variable "aws_region" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "additional_namespaces" {
  type        = list(string)
  default     = []
  description = "List of additional namespaces to create, if they don't exist, that are not defined in a chart"
}

variable "charts" {
  type = list(object({
    name      = string
    directory = string
    namespace = optional(string)
    lifecycle = optional(string)
    resource_cleanup = optional(list(object({
      resource_kind = string
      resource_name = string
      failure_mode  = optional(string)
    })))
  }))
  default     = []
  description = <<EOD
List of charts to install.  Namespaces are automatically created before installing any charts.  Charts are installed
in the order defined, unless overridden by "chart_install_list" value.

Fields:

| Field | Description | Default |
| --- | --- | --- |
| `name` | Name of chart. | - |
| `directory` | Path to directory containing Chart.yaml relative to installer runtime working directory | - |
| `namespace` | Namespace to install chart into | `"default"` |
| `lifecycle` | Lifecycle control.  Allowed values: `[ "ignore", "upgrade", "reinstall" ]` | `"ignore"` |
EOD
}

variable "chart_values_files" {
  type = list(object({
    chart_name   = string
    values_files = list(string)
  }))
  default     = []
  description = <<EOD
List of values files to provide to Helm when installing a chart.  The script will always look for `*.yaml` files
under `{{ pwd }}/chart-values/{{ chart_name }}/*.yaml`, and these files will be appended to that list.
EOD
}

variable "manifests" {
  type = list(object({
    filepath  = string
    namespace = optional(string)
  }))
  default     = []
  description = <<EOD
List of resource manifests to install.  Namespaces are automatically created before applying any manifests.  Manifests
will be applied in the order defined.

Fields:

| Field | Description | Default |
| --- | --- | --- |
| `filepath` | Path to directory containing multiple manifests or path to specific manifest yaml file | - |
| `namespace` | Namespace to apply manifest into | None, will use `namespace` defined in manifest |
EOD
}

variable "charts_to_install" {
  type        = list(string)
  default     = []
  description = <<EOD
If defined, limits the charts to be installed from the provided "charts" list to only these specific ones.  They will
be installed in the order defined in this list.

If empty, all charts will be installed in the order provided in the "charts" variable.
EOD
}

variable "debug" {
  type        = bool
  default     = false
  description = "If true, enables debug output from installer script when run from the wrapper"
}

variable "verbose" {
  type        = bool
  default     = false
  description = "If true, enables verbose logging from installer script when run from the wrapper"
}