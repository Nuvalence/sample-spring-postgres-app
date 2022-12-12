#!/bin/sh

# Generated IronNet Iron Defense installer script
#

exec "${utility_script_filepath}" \
  --customer-name "${customer_name}" \
  --aws-region "${aws_region}" \
  --eks-cluster-name "${eks_cluster_name}"
%{~ for ns in namespaces } \
  --namespace "${ns}"%{ endfor }
%{~ for chart in charts } \
  --chart "${chart.name},${chart.namespace},${chart.lifecycle},${chart.directory}"%{ endfor }
%{~ for chart_values in chart_values_files }%{ for values_file in chart_values.values_files } \
  --chart-values "${chart_values.chart_name},${values_file}"%{ endfor }%{ endfor }
%{~ for chart_name in charts_to_install } \
  --install-chart "${chart_name}"%{ endfor }
%{~ for resource_cleanup in chart_cleanup_resources }\
  --cleanup-chart-resource "${resource_cleanup.chart_name},${resource_cleanup.resource_kind},${resource_cleanup.resource_name},${resource_cleanup.failure_mode}"%{ endfor }
%{~ for manifest in manifests } \
  --manifest "${manifest.filepath},${manifest.namespace}"%{ endfor }
%{~ if debug } \
  --debug%{ endif }
%{~ if verbose } \
  --verbose%{ endif } "$@"