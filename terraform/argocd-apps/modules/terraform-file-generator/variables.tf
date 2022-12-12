variable "repo_root_directory" {
  type        = string
  description = "Root directory where files/directories will be written"
}

variable "local_directory_path" {
  default     = ""
  description = "Local directory path to write files to."
}

variable "values_with_charts" {
  default     = true
  description = "Store values files with helm chart"
}


variable "charts" {
  type = map(object({
    filename = optional(string)

    source_helm_repo = string
    chart_version    = string
    type             = optional(string)
    app_version      = optional(string)
    description      = optional(string)
    dependencies = optional(list(object({
      name       = string
      version    = string
      repository = string
    })))
  }))
  default     = {}
  description = <<EOD
Map of wrapper Helm charts to generate locally.

The key of the map must be the name of the chart.  For example:

```terraform
module "mycharts" {
  source "./modules/file-generator"

  charts = {
    hello-world: {
      helm_repo = "https://helm.github.io/examples"
      chart_version = "0.1.0"
    }
  }
}
```

When run, the above will create the file `$(pwd)/charts/hello-world/Chart.yaml`
with the contents:

```yaml
# Generated Helm Chart for hello-world
#
# Description: Local development wrapper chart for hello-world
#
# Generated on: 2022-07-05T13:47:16Z
#
# Changes are: IGNORED
#
apiVersion: v2
name: "hello-world"
description: |
  Local development wrapper chart for hello-world
type: application
version: "0.1.0"
appVersion: "0.1.0"
dependencies:
  - name: "hello-world"
    version: "0.1.0"
    repository: "https://helm.github.io/examples"
```

If `filename` is left blank, the following template will be used: `charts/{{ chart_name }}/Chart.yaml`
EOD
}

variable "argo_apps" {
  type = map(object({
    filename                = optional(string)
    argo_app_repo           = string
    is_helm_chart           = optional(bool)
    values_file_path_prefix = optional(string)
    namespace               = optional(string)
    path                    = optional(string)
    target_revision         = optional(string)
    auto_update             = optional(bool)
    recurse_dir             = optional(bool)
    additional_sync_options = optional(list(string))
  }))
  default     = {}
  description = <<EOD
Map of ArgoCD Application YAML files to generate.

The map key must be the name of the application, and its recommended this also be the name
of the Helm chart the application is managing.  For example:

```terraform
module "myapps" {
  source "./modules/file-generator"

  argo_apps = {
    hello-world: {
      helm_repo = "https://helm.github.io/examples"
      values_file_path_prefix = "../../chart-values/hello-world/"
    }
  }
}
```

When run, the above will create the file `$(pwd)/apps/hello-world.yaml` with the
following contents:

```yaml
# Generated ArgoCD Application for Helm Chart hello-world
#
# Generated on: 2022-07-05T14:11:29Z
#
# Changes are: IGNORED
#
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world
  namespace: argo-system
spec:
  destination:
        server: 'https://kubernetes.default.svc'
  project: default
  source:
    repoURL: 'https://helm.github.io/examples'
    targetRevision: 'HEAD'
    path: charts/hello-world
    directory:
      recurse: false

    helm:
      ignoreMissingValueFiles: true
      valueFiles:
        - "../../chart-values/hello-world/0-default.yaml"
        - "../../chart-values/hello-world/9-custom.yaml

  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true

    automated:
      prune: true
      selfHeal: true
```

If `filename` is left blank, the following template will be used: `apps/{{ app_name }}.yaml`

EOD
}

variable "chart_values" {
  default     = {}
  description = <<EOD
Map of Helm chart values files to generate.  The key must be the name of the chart.  The value
must be an object as described below:

`override_values` - Pre-Populates values in the generated 9-overrides file, this is handy when values are both generated and defined via the $chart_values variable. A workaround for terraform merge not doing deep merges.

```
  type = map(object({
    path_prefix = optional(string)
    override_values = optional({{ any }})
    data = {{ any }}
  }))
```

We cannot define a strict type on this variable directly due to Terraform type conversion constraints.

For example:

```terraform
module "myapps" {
  source "./modules/file-generator"

  default_chart_values = {
    hello-world: {
      data: {
        really_great_string = "really great value"
        really_great_array_values = [
          "value 1",
          "value 2"
        ]
        really_great_object_value = {
          key1 = "value 1"
          key2 = "value 2"
        }
      }
    }
  }
}
```

When run, the above will create the file `$(pwd)/chart-values/hello-world/0-default.yaml` with
the following contents:

```yaml
# Generated Helm Chart values yaml for hello-world
#
# Generated on: 2022-07-05T14:44:53Z
#
# DO NOT EDIT!  Your changes will be overwritten by Terraform.
#
# This helm values file contains values as defined by the Terraform configuration.  If you wish
# to edit the values for the chart "hello-world", please edit the file "9-overrides.yaml" in
# this directory.
#
"hello-world":
  "really_great_array_values":
  - "value 1"
  - "value 2"
  "really_great_object_value":
    "key1": "value 1"
    "key2": "value 2"
  "really_great_string": "really great value"
```

If `path_prefix` is left blank, the following template will be used: `chart-values/{{ chart_name }}/0-default.yaml`
EOD
}

variable "manifests" {
  default     = []
  description = <<EOD
List of maps of Kubernetes custom resource manifest files to generate.

The value must be an object as described below:

```
  type = list(object({
    filename = optional(string)

    api_version = string
    kind = string
    name = string
    namespace = optional(string)
    labels = optional(map(map(string))
    annotations = optional(map(map(string))
    spec = {{ any }}
  }))
```

We cannot define a strict type on this variable directly due to Terraform type conversion constraints.

module "mymanifests" {
  source "./modules/file-generator"

  manifests = [
    {
      name = "my-great-resource"
      api_version = "fqn.domain.tld/v1"
      kind = "ResourceKind"
      spec = {
        keyOne = "value one"
        keyTwo = {
          subKey = "subValue"
        }
      }
    }
  ]
}

EOD
}
