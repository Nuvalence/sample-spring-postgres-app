# Terraform - Kubernetes Bootstrap Apps

Terraform module to generate Argo-CD Applications to bootstrap an eks cluster

<!-- BEGINNING OF TERRAFORM-DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.2.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.argo_apps](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.chart_values](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.helm_charts](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.manifests](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.chart_values_overrides](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_repo_root_directory"></a> [repo\_root\_directory](#input\_repo\_root\_directory) | Root directory where files/directories will be written | `string` | n/a | yes |
| <a name="input_argo_apps"></a> [argo\_apps](#input\_argo\_apps) | Map of ArgoCD Application YAML files to generate.<br><br>The map key must be the name of the application, and its recommended this also be the name<br>of the Helm chart the application is managing.  For example:<pre>terraform<br>module "myapps" {<br>  source "./modules/file-generator"<br><br>  argo_apps = {<br>    hello-world: {<br>      helm_repo = "https://helm.github.io/examples"<br>      values_file_path_prefix = "../../chart-values/hello-world/"<br>    }<br>  }<br>}</pre>When run, the above will create the file `$(pwd)/apps/hello-world.yaml` with the<br>following contents:<pre>yaml<br># Generated ArgoCD Application for Helm Chart hello-world<br>#<br># Generated on: 2022-07-05T14:11:29Z<br>#<br># Changes are: IGNORED<br>#<br>apiVersion: argoproj.io/v1alpha1<br>kind: Application<br>metadata:<br>  name: hello-world<br>  namespace: argo-system<br>spec:<br>  destination:<br>        server: 'https://kubernetes.default.svc'<br>  project: default<br>  source:<br>    repoURL: 'https://helm.github.io/examples'<br>    targetRevision: 'HEAD'<br>    path: charts/hello-world<br>    directory:<br>      recurse: false<br><br>    helm:<br>      ignoreMissingValueFiles: true<br>      valueFiles:<br>        - "../../chart-values/hello-world/0-default.yaml"<br>        - "../../chart-values/hello-world/9-custom.yaml<br><br>  syncPolicy:<br>    syncOptions:<br>      - CreateNamespace=true<br>      - ApplyOutOfSyncOnly=true<br><br>    automated:<br>      prune: true<br>      selfHeal: true</pre>If `filename` is left blank, the following template will be used: `apps/{{ app_name }}.yaml` | <pre>map(object({<br>    filename                = optional(string)<br>    argo_app_repo           = string<br>    is_helm_chart           = optional(bool)<br>    values_file_path_prefix = optional(string)<br>    namespace               = optional(string)<br>    path                    = optional(string)<br>    target_revision         = optional(string)<br>    auto_update             = optional(bool)<br>    recurse_dir             = optional(bool)<br>    additional_sync_options = optional(list(string))<br>  }))</pre> | `{}` | no |
| <a name="input_chart_values"></a> [chart\_values](#input\_chart\_values) | Map of Helm chart values files to generate.  The key must be the name of the chart.  The value<br>must be an object as described below:<br><br>`override_values` - Pre-Populates values in the generated 9-overrides file, this is handy when values are both generated and defined via the $chart\_values variable. A workaround for terraform merge not doing deep merges.<pre>type = map(object({<br>    path_prefix = optional(string)<br>    override_values = optional({{ any }})<br>    data = {{ any }}<br>  }))</pre>We cannot define a strict type on this variable directly due to Terraform type conversion constraints.<br><br>For example:<pre>terraform<br>module "myapps" {<br>  source "./modules/file-generator"<br><br>  default_chart_values = {<br>    hello-world: {<br>      data: {<br>        really_great_string = "really great value"<br>        really_great_array_values = [<br>          "value 1",<br>          "value 2"<br>        ]<br>        really_great_object_value = {<br>          key1 = "value 1"<br>          key2 = "value 2"<br>        }<br>      }<br>    }<br>  }<br>}</pre>When run, the above will create the file `$(pwd)/chart-values/hello-world/0-default.yaml` with<br>the following contents:<pre>yaml<br># Generated Helm Chart values yaml for hello-world<br>#<br># Generated on: 2022-07-05T14:44:53Z<br>#<br># DO NOT EDIT!  Your changes will be overwritten by Terraform.<br>#<br># This helm values file contains values as defined by the Terraform configuration.  If you wish<br># to edit the values for the chart "hello-world", please edit the file "9-overrides.yaml" in<br># this directory.<br>#<br>"hello-world":<br>  "really_great_array_values":<br>  - "value 1"<br>  - "value 2"<br>  "really_great_object_value":<br>    "key1": "value 1"<br>    "key2": "value 2"<br>  "really_great_string": "really great value"</pre>If `path_prefix` is left blank, the following template will be used: `chart-values/{{ chart_name }}/0-default.yaml` | `map` | `{}` | no |
| <a name="input_charts"></a> [charts](#input\_charts) | Map of wrapper Helm charts to generate locally.<br><br>The key of the map must be the name of the chart.  For example:<pre>terraform<br>module "mycharts" {<br>  source "./modules/file-generator"<br><br>  charts = {<br>    hello-world: {<br>      helm_repo = "https://helm.github.io/examples"<br>      chart_version = "0.1.0"<br>    }<br>  }<br>}</pre>When run, the above will create the file `$(pwd)/charts/hello-world/Chart.yaml`<br>with the contents:<pre>yaml<br># Generated Helm Chart for hello-world<br>#<br># Description: Local development wrapper chart for hello-world<br>#<br># Generated on: 2022-07-05T13:47:16Z<br>#<br># Changes are: IGNORED<br>#<br>apiVersion: v2<br>name: "hello-world"<br>description: |<br>  Local development wrapper chart for hello-world<br>type: application<br>version: "0.1.0"<br>appVersion: "0.1.0"<br>dependencies:<br>  - name: "hello-world"<br>    version: "0.1.0"<br>    repository: "https://helm.github.io/examples"</pre>If `filename` is left blank, the following template will be used: `charts/{{ chart_name }}/Chart.yaml` | <pre>map(object({<br>    filename = optional(string)<br><br>    source_helm_repo = string<br>    chart_version    = string<br>    type             = optional(string)<br>    app_version      = optional(string)<br>    description      = optional(string)<br>    dependencies = optional(list(object({<br>      name       = string<br>      version    = string<br>      repository = string<br>    })))<br>  }))</pre> | `{}` | no |
| <a name="input_local_directory_path"></a> [local\_directory\_path](#input\_local\_directory\_path) | Local directory path to write files to. | `string` | `""` | no |
| <a name="input_manifests"></a> [manifests](#input\_manifests) | List of maps of Kubernetes custom resource manifest files to generate.<br><br>The value must be an object as described below:<pre>type = list(object({<br>    filename = optional(string)<br><br>    api_version = string<br>    kind = string<br>    name = string<br>    namespace = optional(string)<br>    labels = optional(map(map(string))<br>    annotations = optional(map(map(string))<br>    spec = {{ any }}<br>  }))</pre>We cannot define a strict type on this variable directly due to Terraform type conversion constraints.<br><br>module "mymanifests" {<br>  source "./modules/file-generator"<br><br>  manifests = [<br>    {<br>      name = "my-great-resource"<br>      api\_version = "fqn.domain.tld/v1"<br>      kind = "ResourceKind"<br>      spec = {<br>        keyOne = "value one"<br>        keyTwo = {<br>          subKey = "subValue"<br>        }<br>      }<br>    }<br>  ]<br>} | `list` | `[]` | no |
| <a name="input_values_with_charts"></a> [values\_with\_charts](#input\_values\_with\_charts) | Store values files with helm chart | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argo_apps"></a> [argo\_apps](#output\_argo\_apps) | Provided Argo app definitions |
| <a name="output_chart_values"></a> [chart\_values](#output\_chart\_values) | Provided chart value file definitions |
| <a name="output_charts"></a> [charts](#output\_charts) | Provided chart definitions |
| <a name="output_manifests"></a> [manifests](#output\_manifests) | Provided manifest definitions |
| <a name="output_rendered_argo_apps"></a> [rendered\_argo\_apps](#output\_rendered\_argo\_apps) | Any / all rendered Argo app files |
| <a name="output_rendered_chart_values"></a> [rendered\_chart\_values](#output\_rendered\_chart\_values) | Any / all rendered Helm chart values.yaml files |
| <a name="output_rendered_charts"></a> [rendered\_charts](#output\_rendered\_charts) | Any / all rendered Helm chart files |
| <a name="output_rendered_manifests"></a> [rendered\_manifests](#output\_rendered\_manifests) | Any / all rendered Kubernetes custom resource manifest files |
<!-- END OF TERRAFORM-DOCS HOOK -->