#!/usr/bin/env bash

set -e

# IronDefense utility script
#
# This script is intended to be run after a terraform apply

#### CHANGELOG
#
# 20220825.0
# - Correcting chart install logic to ensure correct order
#
# 20220824.0
# - Fixed incorrect delimiter character in chart values readarray call
# - Correctly sorting values files
#
# 20220808.0
# - Added --cleanup-chart-resource flag
# - Misc log output cleanup
#
# 20220805.0
# - Added "upgrade-with-crds" lifecycle option
# - Minor internal cleanup
# - Actually wiring up --no-color flag
#
# 20220804.0
# - Updated help doc verbiage
# - Added --apply-manifest flag
# - Added flow control funcs
# - Added --no-color flag
#
# 20220729.0
# - Added check to ensure all --install-chart names are represented in --chart
# - Preventing executable checks from error'ing whole run
#
# 20220727.0
# - Correcting bash version info check variable
#
# 20220726.0
# - Continued work from 0725
# - Added common _build_working_dir_relative_path func to use for all path building operations
# - Added --chart-values flag
# - Fixed whitespace trimming in _split_arg_value
# - Clarifying and cleaning up help text
#
# 20220725.0
# - Added support for chart directory in --chart tuple
# - Added --install-chart flag
# - Removed --skip-argo-cd flag
#
# 20220720.0
# - Bugfixes and cleanup, preparing for use
#
# 20220719.0
# - Misc cleanup
# - Renamed script to "utility" from "installer" as it may eventually do a lot more.
#
# 20220715.0
# - Added "--namespace" flag
# - Added "--chart" flag
# - Added "--manifest" flag
# - Adding kubectl context selector
# - Misc bugfixes
#
# 20220714.0
# - Initial revision

### Constants

# this must be manually updated
_SCRIPT_VERSION="20220825.0"

# find required executable locations
set +e
_BIN_AWS="$(which aws)"
_BIN_KUBECTL="$(which kubectl)"
_BIN_HELM="$(which helm)"
_BIN_JQ="$(which jq)"
set -e

# where is we
_WORKING_DIR="$(pwd)"

# no need to change this.
_LOG_DATE_FORMAT="+%T"

# possible lifecycle values
_LIFECYCLE_IGNORE="ignore"
_LIFECYCLE_UPGRADE="upgrade"
_LIFECYCLE_REINSTALL="reinstall"
_LIFECYCLE_DEFAULT="${_LIFECYCLE_IGNORE}"

# possible resource cleanup failure modes
_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE="continue"
_CLEANUP_RESOURCE_FAILURE_MODE_FAIL="fail"
_CLEANUP_RESOURCE_FAILURE_MODE_DEFAULT="${_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE}"

### Variables

# general options
_var_debug=
_var_verbose=
_var_really_verbose=

_var_no_color=

# flow control
_var_skip_update_kubeconfig=
_var_skip_all_namespaces=
_var_skip_external_secrets=
_var_skip_all_charts=
_var_skip_all_manifests=

# required vars
_var_customer_name=
_var_aws_region=
_var_eks_cluster_name=

# k8s config
_var_namespaces=()
_var_install_chart_names=()
_var_apply_manifest_filepaths=()

_var_chart_names=()
_var_chart_namespaces=()
_var_chart_lifecycles=()
_var_chart_directories=()

_var_chart_values_chart_names=()
_var_chart_values_filepaths=()

_var_manifest_filepaths=()
_var_manifest_namespaces=()

_var_chart_cleanup_chart_names=()
_var_chart_cleanup_resource_kinds=()
_var_chart_cleanup_resource_names=()
_var_chart_cleanup_failure_modes=()

### Bash version check

# this script requires bash >= 4.4
if (( BASH_VERSINFO[0] < 4 )) || ( (( BASH_VERSINFO[0] == 4 )) && (( BASH_VERSINFO[1] < 4 )) )
then
  echo "Sorry, this script requires bash 4.4 or newer.  You are running \"${BASH_VERSINFO[*]}\""
  echo ""
  echo "If you're on a Mac, do the following:"
  echo "1. Execute \"brew install bash\""
  echo "2. Close and reopen your terminal (or execute \"exec \$SHELL --login\")"
  echo "3. Execute \"bash --version\""
  echo "  - If you still see version 3.x, you will need to put the homebrew installed version of bash earlier in your \$PATH"
  echo "  - One easy way to do this is to ensure \"/usr/local/bin\" is earlier than \"/usr/bin\" in your \$PATH"
  echo ""
  exit 1
fi

### Functions

# Private: Returns 0 if --no-color is not passed at runtime
can_colorize_output() {
  if [ -z "${_var_no_color}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --verbose was passed at runtime
is_verbose() {
  if [ -n "${_var_verbose}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: returns 0 if --really-verbose was passed at runtime
is_really_verbose() {
  if [ -n "${_var_really_verbose}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --debug was passed at runtime
is_debug() {
  if [ -n "${_var_debug}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Exit successfully
#
# Optionally print a message then exit 0
#
# $1 - (Optional) message to print before exiting
exit_success() {
  if [[ -n "${1}" ]]; then
    echo "${1}"
  fi
  exit 0
}

# Private: Print error message
#
# Optionally print a message then exit 1
#
# $1 - (Optional) message to print before exiting
exit_error() {
  if [[ -n "${1}" ]]; then
    echo "${1}"
  fi
  exit 1
}

# Private: Build log date value
log_date() {
  if [ -n "${_LOG_DATE_FORMAT}" ]; then
    date "${_LOG_DATE_FORMAT}"
  else
    date '+%T'
  fi
}

# Private: Info-level logger
#
# Logs to stdout
#
# $# - Values to print
log_info() {
  local d
  local msgs
  d="$(log_date)"
  msgs=("${@}")

  if can_colorize_output ; then
    echo -en '\x1b[38;5;39m[INFO ]\x1b[0m'
  else
    echo -n "[INFO ]"
  fi

  echo " (${d}) ${msgs[*]}"
}

# Private: Error level logger
#
# Logs to stdout
#
# $# - Values to print
log_err() {
  local d
  local msgs
  d="$(log_date)"
  msgs=("${@}")

  if can_colorize_output ; then
    echo -en '\x1b[31m[ERROR]\x1b[0m'
  else
    echo -n "[ERROR]"
  fi

  echo " (${d}) ${msgs[*]}"
}

# Private: Debug-level logger
#
# Only prints logs when --verbose is provided
#
# $# - Values to print
log_debug() {
  if is_verbose ; then
    local d
    local msgs
    d="$(log_date)"
    msgs=("${@}")

    if can_colorize_output ; then
      echo -en '\x1b[38;5;109m[DEBUG]\x1b[0m'
    else
      echo -n "[DEBUG]"
    fi

    echo " (${d}) ${msgs[*]}"
  fi
}

# Private: Verbose-level logger
#
# Only prints when --really-verbose is provided
#
# $# - Values to print
log_verbose() {
  if is_really_verbose; then
    local d
    local msgs
    d="$(log_date)"
    msgs=("${@}")

    if can_colorize_output; then
      echo -en '\x1b[38;5;104m[VERBO]\x1b[0m'
    else
      echo -n "[VERBO]"
    fi

    echo " (${d}) ${msgs[*]}"
  fi
}

## Flow control funcs

# Private: Return 0 if --skip-update-kubeconfig is not set at runtime
_can_update_kubeconfig() {
  if [ -z "${_var_skip_update_kubeconfig}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --skip-all-namespaces is not set at runtime
_can_create_namespaces() {
  if [ -z "${_var_skip_all_namespaces}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --skip-external-secrets is not set at runtime
_can_bootstrap_external_secrets() {
  if [ -z "${_var_skip_external_secrets}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --skip-all-charts is not set at runtime
_can_install_charts() {
  if [ -z "${_var_skip_all_charts}" ]; then
    return 0
  else
    return 1
  fi
}

# Private: Returns 0 if --skip-all-manifests is not set at runtime
_can_apply_manifests() {
  if [ -z "${_var_skip_all_manifests}" ]; then
    return 0
  else
    return 1
  fi
}

## Helper funcs

# Private: Find position of character in string
#
# Attempts to locate a given needle $2 inside haystack $1
#
# $1 - Haystack to search within
# $2 - Needle to attempt to find in haystack
#
# Examples:
#
#   epos="$(_strpos 'my great string' 'e')"
#   echo "${epos}" # 5
_strpos() {
  local haystack
  local needle
  local i
  local pos
  local haystack_len
  local needle_len

  haystack="${1}"
  needle="${2}"
  pos="-1"
  haystack_len="${#haystack}"
  needle_len="${#needle}"

  for ((i = 0; i + needle_len <= haystack_len; i++)); do
    if [[ "${needle}" == "${haystack:$i:$needle_len}" ]]; then
      pos="${i}"
      break
    fi
  done

  echo "${pos}"
}

# Private: Split arg value by comma.  Each segment of the tuple is whitespace trimmed.
#
# $1 - Array variable to populate
# $2 - Value to split
_split_arg_value() {
  local -n _out="${1}"
  local _value="${2}"

  IFS=',' read -ra _out <<< "$(echo -n "${_value}" | sed -r 's/^[ ]+//g; s/[ ]+$//g')"
}

# Private: Trim a given string for leading slashes and leading and trailing whitespace
#
# $1 - String to trim
_trim_path_segment() {
  local _path_segment="${1}"

  echo -n "${_path_segment}" | sed -r 's/^[ \/]+//g; s/[ ]+$//g'
}

# Private: Build path relative to working dir
#
# $1 - Relative path segment to append.  Value will be trimmed
_build_working_dir_relative_path() {
  local _path="${1}"
  echo "${_WORKING_DIR}/$(_trim_path_segment "${_path}")"
}

# Private: Build path to a given Helm chart directory
#
# $1 - Name of Helm chart
_get_chart_dir() {
  local _chart_name="${1}"

  # look for configured chart dir path
  for (( i = 0; i < "${#_var_chart_names[@]}"; ++i ))
  do
    if [[ "${_var_chart_names[$i]}" == "${_chart_name}" ]]; then
      echo "${_var_chart_directories[$i]}"
      return 0
    fi
  done

  # if we reach here, return default path
  _build_working_dir_relative_path "charts/${_chart_name}"
}

# Private: Build path to the directory containing a given Helm chart's values.yaml file(s)
_get_chart_values_dir() {
  local _chart_name="${1}"
  _build_working_dir_relative_path "chart-values/${_chart_name}"
}

# Private: Get path to manifest directory or subdirectory
#
# $1 - Optional subdirectory under "manifests"
_get_manifest_path() {
  local _sub_path="${1:-}"
  if [ -z "${_sub_path}" ]; then
    _build_working_dir_relative_path "manifests"
  else
    _build_working_dir_relative_path "manifests/${_sub_path}"
  fi
}

# Private: Add --values args to Helm command list
#
# $1 - Current args array
# $2 - Helm chart name
_add_chart_values_args() {
  local -n _arg_list="${1}"
  local _chart_name="${2}"

  local _chart_values_dir
  local _file_list=()

  _chart_values_dir="$(_get_chart_values_dir "${_chart_name}")"

  log_debug "Looking for yaml files in \"${_chart_values_dir}\"..."

   # look for values files in default directory
  if [ -d "${_chart_values_dir}" ]; then

    # pulled from https://stackoverflow.com/a/54561526/11101981 and i love it.
    readarray -d $'\n' _file_list < <(sort <<< "$(find "${_chart_values_dir}" -type f -name '*.yaml')")

    for (( i = 0; i < "${#_file_list[@]}"; ++i ));
    do
      _file_list[$i]="$(echo -n "${_file_list[$i]}" | tr -d '\n')"
    done

    log_debug "Found ${#_file_list[@]} value file(s)"

    if is_verbose; then
      for f in "${_file_list[@]}";
      do
        log_verbose "Values file: ${f}"
      done
    fi

    for values_file in "${_file_list[@]}"
    do
      _arg_list+=("--values" "${values_file}")
    done
  fi

  # add any manually specified values files for this chart
  for (( i = 0; i < "${#_var_chart_values_chart_names[@]}"; ++i ))
  do
    if [[ "${_var_chart_values_chart_names[$i]}" == "${_chart_name}" ]]; then
      if [[ "${_var_chart_values_filepaths[$i]}" = "${_chart_values_dir}"* ]]; then
        log_debug "Skipping manually defined values file \"${_var_chart_values_filepaths[$i]}\" as it is in the default path"
      else
        log_debug "Adding manually defined values file \"${_var_chart_values_filepaths[$i]}\""
        _arg_list+=("--values" "${_var_chart_values_filepaths[$i]}")
      fi
    fi
  done
}

## Exec funcs

# Private: Adds customer EKS cluster to local kubeconfig
#
# $1 - AWS Region
# $2 - Customer EKS cluster name
_exec_update_kubeconfig() {
  local _aws_region="${1}"
  local _cluster_name="${2}"

  local _out
  local _rc

  log_info "Adding kubeconfig entry for EKS cluster \"${_cluster_name}\" in region \"${_aws_region}\"..."

  set +e
  _out="$("${_BIN_AWS}" eks update-kubeconfig --region "${_aws_region}" --name "${_cluster_name}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "unable to update kubeconfig"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_debug "kubeconfig entry added / updated"
  log_verbose "${_out}"
}

# Private: Switch local kubectl context to the provided cluster
#
# $1 - Name of cluster to switch context to
_exec_switch_kubectl_context() {
  local _cluster_name="${1}"

  local _out
  local _rc

  log_info "Switching kubectl context to \"${_cluster_name}\""

  set +e
  _out="$("${_BIN_KUBECTL}" config set-context "${_cluster_name}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error switching kubectl context"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_debug "kubectl context updated"
  log_verbose "${_out}"
}

# Private: Execute Helm dep update for a given chart
#
# $1 - Name of chart
# $2 - Directory containing Chart.yaml
_exec_helm_dep_update() {
  local _chart_name="${1}"
  local _chart_dir="${2}"

  local _out
  local _rc

  log_info "Updating deps for chart" "${_chart_name}"

  set +e
  _out="$("${_BIN_HELM}" dep update "${_chart_dir}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error updating deps for chart" "\"${_chart_name}\"" ":"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_debug "Chart \"${_chart_name}\" deps updated successfully"
  log_verbose "${_out}"
}

# Private: Perform chart-specific resource cleanup
#
# $1 - Name of chart
# $2 - Resource kind
# $3 - Resource name
# $4 - Failure mode
_exec_cleanup_chart_resources() {
  local _chart_name="${1}"
  local _resource_kind="${2}"
  local _resource_name="${3}"
  local _failure_mode="${4}"

  local _out
  local _rc

  log_debug "Cleaning up resource \"${_resource_kind}\" \"${_resource_name}\" for chart \"${_chart_name}\"..."

  if [[ "${_failure_mode}" == "${_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE}" ]]; then
    set +e
  fi

  _out="$("${_BIN_KUBECTL}" delete "${_resource_kind}" "${_resource_name}" 2>&1)"
  _rc=$?

  if [[ "${_failure_mode}" == "${_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE}" ]]; then
    set -e
  fi

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error deleting resource \"${_resource_kind}\" \"${_resource_name}\":"
    log_err "${_out}"
    log_info "Failure mode set to \"${_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE}\", continuing execution"
  else
    log_info "Deleted resource \"${_resource_kind}\" \"${_resource_name}\""
    log_verbose "${_out}"
  fi

  return 0
}

# Private: Execute any chart resource cleanup actions, if there are any
#
# $1 - Name of chart
_exec_chart_cleanup() {
  local _chart_name="${1}"

  local _cni
  local _resource_kind
  local _resource_name
  local _failure_mode

  # loop through configured list of resources to clean up, matching on chart name
  for ((_cni=0; _cni < "${#_var_chart_cleanup_chart_names[@]}"; _cni+=1))
  do
    if [[ "${_chart_name}" == "${_var_chart_cleanup_chart_names[$_cni]}" ]]; then

      # if chart name match, get config opts

      _resource_kind="${_var_chart_cleanup_resource_kinds[$_cni]}"
      _resource_name="${_var_chart_cleanup_resource_names[$_cni]}"
      _failure_mode="${_var_chart_cleanup_failure_modes[$_cni]}"

      # perform cleanup
      _exec_cleanup_chart_resources "${_chart_name}" "${_resource_kind}" "${_resource_name}" "${_failure_mode}"

    fi
  done
}

# Private: Determines if a given chart is already installed in the target namespace
#
# $1 - Name of chart
# $2 - Namespace to look in
_exec_is_chart_installed() {
  local _chart_name="${1}"
  local _chart_namespace="${2}"

  local _out
  local _rc

  log_info "Checking if chart \"${_chart_name}\" is already installed into namespace \"${_chart_namespace}\"..."

  set +e
  _out="$("${_BIN_HELM}" get notes --namespace "${_chart_namespace}" "${_chart_name}" 2>&1)"
  _rc=$?
  set -e

  if [ -n "${_out}" ]; then
    log_verbose "${_out}"
  fi

  return "${_rc}"
}

# Private: Execute Helm install of a specific chart with values
#
# $1 - Name of chart
# $2 - Namespace to deploy into
# $3 - Directry containing Chart.yaml
# $4 - Name of customer
_exec_helm_install() {
  local _chart_name="${1}"
  local _chart_namespace="${2}"
  local _chart_dir="${3}"
  local _customer_name="${4}"

  local _args
  local _out
  local _rc

  log_info "Attempting install of chart \"${_chart_name}\" in namespace \"${_chart_namespace}\"..."

  _args=(
    "install"
    "${_chart_name}"
    "${_chart_dir}"
    "--namespace" "${_chart_namespace}"
  )

  # add -f arg(s)
  _add_chart_values_args _args "${_chart_name}" "${_customer_name}"

  # just in case, although this should not be necessary if the logic of the script is sound...
  if [[ "${_chart_namespace}" != "default" ]]; then
    _args+=("--create-namespace")
  fi

  log_verbose "helm args: ${_args[*]}"

  set +e
  _out="$("${_BIN_HELM}" "${_args[@]}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error installing chart" "\"${_chart_name}\"" "into namespace" "\"${_chart_namespace}\"" ":"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_info "Chart" "\"${_chart_name}\"" "installed into namespace" "\"${_chart_namespace}\"" "successfully!"
  log_verbose "${_out}"
}

# Private: Executes Helm upgrade of a specific chart with values
#
# $1 - Name of chart
# $2 - Namespace to deploy into
# $3 - Directory containing Chart.yaml
# $4 - Name of customer
_exec_helm_upgrade() {
  local _chart_name="${1}"
  local _chart_namespace="${2}"
  local _chart_dir="${3}"
  local _customer_name="${4}"

  local _args
  local _out
  local _rc

  log_info "Attempting upgrade of chart" "\"${_chart_name}\"" "in namespace" "\"${_chart_namespace}\"" "..."

  _args=(
    "upgrade"
    "${_chart_name}"
    "${_chart_dir}"
    "--namespace" "${_chart_namespace}"
    "--dependency-update"
  )

  # add -f arg(s)
  _add_chart_values_args _args "${_chart_name}" "${_customer_name}"

  log_verbose "helm args: ${_args[*]}"

  set +e
  _out="$("${_BIN_HELM}" "${_args[@]}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error upgrading chart" "\"${_chart_name}\"" "in namespace" "\"${_chart_namespace}\"" ":"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_info "Chart" "\"${_chart_name}\"" "in namespace" "\"${_chart_namespace}\"" "successfully upgraded!"
  log_verbose "${_out}"
}

# Private: Executes Helm uninstall of a specific chart
#
# $1 - Name of chart
# $2 - Namespace to remove from
_exec_helm_uninstall() {
  local _chart_name="${1}"
  local _chart_namespace="${2}"

  local _args
  local _out
  local _rc

  log_info "Attempting to uninstall chart" "\"${_chart_name}\"" "from namespace" "\"${_chart_namespace}\"" "..."

  _args=(
    "uninstall"
    "${_chart_name}"
    "--namespace" "${_chart_namespace}"
    "--wait"
    "--timeout" '10m0s'
  )

  log_verbose "helm args: ${_args[*]}"

  set +e
  _out="$("${_BIN_HELM}" "${_args[@]}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error uninstalling chart" "\"${_chart_name}\"" "from namespace" "\"${_chart_namespace}\"" ":"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_info "Chart" "\"${_chart_name}\"" "uninstalled from namespace" "\"${_chart_namespace}\"" "successfully!"
  log_verbose "${_out}"
}

# Private: Wait for a given pod's deployment to be "OK"
#
# $1 - Name of pod without "deployment/" prefix
# $2 - Deployment namespace
# $3 - Delay between attempts (defaults to 10 seconds)
# $4 - Maximum number of attempts (defaults to 10 attempts)
_exec_wait_for_pod_ok() {
  local _pod_name="${1}"
  local _pod_namespace="${2}"
  local _attempt_delay="${3:-10}"
  local _attempt_limit="${4:-10}"

  local _rc
  local _out
  local _attempts

  _rc=1
  _attempts=0

  log_debug "Waiting for pod" "\"${_pod_name}\"" "in namespace" "\"${_pod_namespace}\"" "to be \"healthy\"..."

  while [ "${_rc}" -ne 0 ] && [ "${_attempts}" -lt "${_attempt_limit}" ]; do
    sleep "${_attempt_delay}"
    _attempts+=1
    set +e
    _out="$("${_BIN_KUBECTL}" rollout status "deployment/${_pod_name}" -n "${_pod_namespace}" 2>&1)"
    _rc=$?
    set -e

    log_verbose "${_out}"

  done

  # if it never became healthy, print last seen output
  if [ "${_rc}" -ne 0 ]; then
    log_err "Pod" "${_pod_name}" "in namespace" "${_pod_namespace}" "was not healthy in time"
  fi

  return "${_rc}"
}

# Private: Create k8s namespace should it not exist
#
# $1 - Name of namespace to ensure exists
_exec_ensure_k8s_namespace_exists() {
  local _namespace="${1}"

  local _status
  local _out
  local _rc

  set +e
  _status="$("${_BIN_KUBECTL}" get ns "${_namespace}" -o json 2>&1 | "${_BIN_JQ}" -r '.status.phase' 2>&1)"
  _rc=$?
  set -e

  # TODO: test for other status phases?

  if [[ "${_status}" == "Active" ]]; then
    log_debug "Namespace" "${_namespace}" "already exists"
    return 0
  fi

  log_info "Namespace" "${_namespace}" "not found, attempting to create..."

  set +e
  _out="$("${_BIN_KUBECTL}" create namespace "${_namespace}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error creating namespace \"${_namespace}\""
    echo "${_out}"
    exit "${_rc}"
  fi

  log_info "Namespace" "${_namespace}" "successfully created."
  log_verbose "${_out}"
}

# Private: Apply manifests, optionally from a specific directory
#
# $1 - Path to specific manifest file or directory
# $2 - Namespace to apply manifests in
# $3 - If defined, uses adds "--recursive" flag to "kubectl apply" call
_exec_apply_manifests() {
  local _manifest_path="${1}"
  local _namespace="${2}"
  local _recursive="${3:-}"

  local _target_path
  local _args
  local _out
  local _rc

  _target_path="$(_get_manifest_path "${_manifest_path}")"

  log_info "Installing manifest(s):" "${_target_path}"

  _args=(
    "apply"
    "-f" "${_target_path}"
  )

  if [ -n "${_namespace}" ]; then
    _args+=("--namespace" "${_namespace}")
  fi

  if [ -n "${_recursive}" ]; then
    _args+=("--recursive")
  fi

  set +e
  _out="$("${_BIN_KUBECTL}" "${_args[@]}" 2>&1)"
  _rc=$?
  set -e

  if [ "${_rc}" -ne 0 ]; then
    log_err "Error applying manifests"
    echo "${_out}"
    exit "${_rc}"
  fi

  log_debug "Manifests installed successfully"
  log_verbose "${_out}"
}

#### Help text

_help_text() {
  cat <<EOD;
IronDefense Utility Script (version: "${_SCRIPT_VERSION}")

While this script is intended to be run via the wrapper, you are free to execute it
yourself.

Prerequisites:
1. aws, jq, kubectl, and helm cli utilities must be installed.
2. Your shell must have an active AWS login, either via aws-sso-helper or assume

Options:
  [Flag]                                  [Description]
  --help                                  Prints this help message
  --debug                                 Enables debug output
  --verbose                               Enables verbose logging
  --really-verbose                        Enables really verbose logging
  --no-color                              Disable ANSI highlighting

  --customer-name <value>                 Name of customer
  --aws-region <value>                    AWS region being deployed to
  --eks-cluster-name <value>              Name of EKS cluster created for this deployment

  --namespace <value>                     Name of Kubernetes namespace to ensure exists
                                            - May be specified multiple times
                                            - Namespaces created in order defined

  --chart "<name[,namespace[,lifecycle[,directory]]]>"
                                          Comma separated tuple of "chart-name,deploy-namespace,lifecycle,directory" of
                                          Helm chart to install.
                                            - If "namespace" is empty, chart will be installed into "default"
                                            - Possible "lifecycle" values:
                                              - ${_LIFECYCLE_IGNORE}  (default)  - If chart already installed, ignore on later runs
                                              - ${_LIFECYCLE_UPGRADE}            - If chart already installed, attempt upgrade
                                              - ${_LIFECYCLE_REINSTALL}          - If chart already installed, uninstall then install
                                            - If "directory" is empty, defaults to "{ pwd }/charts/{ chart-name }"
                                              - If provided, value MUST be relative to the runtime working directory.
                                            - Charts are installed in the order defined here, unless overridden by
                                              --install-chart flag.

  --install-chart <name>
                                          Specific chart to install.
                                            - If not defined, all charts set with --chart will be installed in the order
                                              they were set.
                                            - May be specified multiple times
                                            - Charts installed in order defined

  --cleanup-chart-resource <chart_name,resource_kind,resource_name[,failure_mode]>
                                          Specifies list of resources to delete from the cluster when uninstalling
                                          a specific chart.
                                            - "chart_name" must be the name of the chart that owns these resources
                                            - "resource_kind" must be the API name of the resource, e.g. "customresourcedefinitions.apiextensions.k8s.io"
                                            - "resource_name" must be the type of resource to delete, e.g. "domeparticipants.iron-central.ironnet.io"
                                            - "failure_mode" may be one of:
                                              - "${_CLEANUP_RESOURCE_FAILURE_MODE_CONTINUE}" (default)    - continue execution if an error is seen
                                              - "${_CLEANUP_RESOURCE_FAILURE_MODE_FAIL}"                  - stop execution if an error is seen

  --chart-values "<chart_name,filepath>"
                                          Optionally specify directory containing values yaml files for a given Helm
                                          chart.
                                            - Script always looks for files in "{ pwd }/chart-values/{ chart_name }/*"
                                            - Files provided here will be appended after any / all files found in
                                              default directory.
                                            - The value of "filepath" MUST be relative to the runtime working directory.
                                            - May be specified multiple times, including for the same chart.
                                            - Values files appended in order defined.

  --manifest "<filepath[,namespace]>"
                                          Filepath of resource manifest to apply to cluster.
                                            - The value of "filepath" MUST be relative to the runtime working directory.
                                            - If ",{namespace}" not provided, will default to namespace in manifest
                                            - May be specified multiple times

  --apply-manifest <filepath>             Specific manifest to apply.
                                            - If not defined, all manifests set with --manifest will be applied in the
                                              order they were set.
                                            - May be specified multiple times
                                            - Manifests are applied in the order defined

  --skip-update-kubeconfig                Prevents script from modifying kubeconfig and kubectl context
  --skip-all-namespaces                   Prevents script from creating any namespaces
  --skip-external-secrets                 Prevents script from launching external-secrets controller
                                            and installing external-secrets manifests
  --skip-all-charts                       Prevents script from installing / upgrading any Helm charts
  --skip-all-manifests                    Prevents script from applying any resource manifests
EOD
}

#### Execution

### Debug check

# immediately test for --debug flag
for flag in "${@}"
do
  if [[ "${flag}" == "--debug" ]]; then
    log_info "Enabling debug output"
    _var_debug=1
    set -x
    break
  fi
done

### Flag parser
while [[ $# -gt 0 ]]; do

  _eq_pos="$(_strpos "${1}" '=')"

  _shift_2=
  _valued=

  if [ "${_eq_pos}" -ne -1 ]; then
    _arg="$(echo -n "${1}" | cut -d '=' -f1)"
    _value="$(echo -n "${1}" | cut -s -d '=' -f2)"
  else
    _arg="${1}"
    _value="${2:-}"
    _shift_2=1
  fi

  case "${_arg}" in
  # general options
  -h | -\? | --h | --help)
    exit_success "$(_help_text)"
    ;;
  --debug)
    _var_debug=1
    ;;
  -v | --verbose)
    _var_verbose=1
    ;;
  -vv | --really-verbose)
    _var_really_verbose=1
    ;;

  --no-color)
    _var_no_color=1
    ;;

  # required vars

  --customer-name)
    _var_customer_name="${_value}"
    _valued=1
    ;;
  --aws-region)
    _var_aws_region="${_value}"
    _valued=1
    ;;
  --eks-cluster-name)
    _var_eks_cluster_name="${_value}"
    _valued=1
    ;;

  # k8s and helm flags

  --namespace)
    _var_namespaces+=("${_value}")
    _valued=1
    ;;

  # chart value has format "name,namespace,lifecycle,directory"
  --chart)
    _tmp=()
    _split_arg_value _tmp "${_value}"
    _var_chart_names+=("${_tmp[0]}")
    if [ -n "${_tmp[1]}" ]; then
      _var_chart_namespaces+=("${_tmp[1]}")
    else
      _var_chart_namespaces+=("default")
    fi
    if [ -n "${_tmp[2]}" ]; then
      _var_chart_lifecycles+=("${_tmp[2]}")
    else
      _var_chart_lifecycles+=("${_LIFECYCLE_DEFAULT}")
    fi
    if [ -n "${_tmp[3]}" ]; then
      _var_chart_directories+=("$(_build_working_dir_relative_path "${_tmp[3]}")")
    else
      _var_chart_directories+=("$(_get_chart_dir "${_tmp[0]}")")
    fi
    _valued=1
    ;;

  --install-chart)
    _var_install_chart_names+=("${_value}")
    _valued=1
    ;;

  # chart-values value has format "chart_name,values_directory"
  --chart-values)
    _tmp=()
    _split_arg_value _tmp "${_value}"
    _var_chart_values_chart_names+=("${_tmp[0]}")
    _var_chart_values_filepaths+=("$(_build_working_dir_relative_path "${_tmp[1]}")")
    _valued=1
    ;;

  # chart cleanup resources has format "chart_name,resource_kind,resource_name,failure_mode"
  --cleanup-chart-resource)
    _tmp=()
    _split_arg_value _tmp "${_value}"
    _var_chart_cleanup_chart_names+=("${_tmp[0]}")
    _var_chart_cleanup_resource_kinds+=("${_tmp[1]}")
    _var_chart_cleanup_resource_names+=("${_tmp[2]}")
    if [ -n "${_tmp[3]}" ]; then
      _var_chart_cleanup_failure_modes+=("${_tmp[3]}")
    else
      _var_chart_cleanup_failure_modes+=("${_CLEANUP_RESOURCE_FAILURE_MODE_DEFAULT}")
    fi
    _valued=1
    ;;

  # manifest value has format "filepath,namespace"
  --manifest)
    _tmp=()
    _split_arg_value _tmp "${_value}"
    _var_manifest_filepaths+=("${_tmp[0]}")
    if [ -n "${_tmp[1]}" ]; then
      _var_manifest_namespaces+=("${_tmp[1]}")
    else
      _var_manifest_namespaces+=("")
    fi
    _valued=1
    ;;

  --apply-manifest)
    _var_apply_manifest_filepaths+=("${_value}")
    _valued=1
    ;;

  # flow control

  --skip-update-kubeconfig)
    _var_skip_update_kubeconfig=1
    ;;
  --skip-all-namespaces)
    _var_skip_all_namespaces=1
    ;;
  --skip-external-secrets)
    _var_skip_external_secrets=1
    ;;
  --skip-all-charts)
    _var_skip_all_charts=1
    _valued=1
    ;;
  --skip-all-manifests)
    _var_skip_all_manifests=1
    ;;

  # catch-all
  *)
    _help_text
    exit_error "\"${_arg}\" is not a known flag"
    ;;
  esac

  # shift us onto next arg
  shift

  # optionally skip passed valued option
  if [ -n "${_valued}" ] && [ -n "${_shift_2}" ]; then
    shift
  fi
done

# executable check

if [ -f "${_BIN_AWS}" ]; then
  log_debug "aws found: ${_BIN_AWS}"
else
  exit_error "aws cli not found"
fi
if [ -f "${_BIN_KUBECTL}" ]; then
  log_debug "kubectl found: ${_BIN_KUBECTL}"
else
  exit_error "kubectl not found"
fi
if [ -f "${_BIN_HELM}" ]; then
  log_debug "helm found: ${_BIN_HELM}"
else
  exit_error "helm not found"
fi
if [ -f "${_BIN_JQ}" ]; then
  log_debug "jq found: ${_BIN_JQ}"
else
  exit_error "jq not found"
fi

# required var check
if [ -z "${_var_aws_region}" ]; then
  exit_error "Missing required flag \"--aws-region\""
fi
if [ -z "${_var_eks_cluster_name}" ]; then
  exit_error "Missing required flag \"--eks-cluster-name\""
fi
if [ -z "${_var_customer_name}" ]; then
  exit_error "Missing required flag \"--customer-name\""
fi

# TODO: turn the next few into a func, ya dingus.

# verify all --install-chart chart names exist in --chart list
if _can_install_charts && [ "${#_var_install_chart_names[@]}" -gt 0 ] ; then
  log_verbose "Ensuring all charts set to --install-chart exist in --chart list"
  _found=()
  _excess=()
  for icn in "${_var_install_chart_names[@]}"
  do
    for cn in "${_var_chart_names[@]}"
    do
      if [[ "${cn}" == "${icn}" ]]; then
        _found+=("${icn}")
        continue 2
      fi
    done
    _excess+=("${icn}")
  done

  if [ "${#_excess[@]}" -gt 0 ]; then
    log_err "There are chart names present in the --install-chart list not found in --chart args: ${_excess[*]}"
    log_err "  --chart names         : ${_var_chart_names[*]}"
    log_err "  --install-chart names : ${_var_install_chart_names[*]}"
    exit_error "Please either correct name provided to --install-chart or ensure all charts are present in a --chart arg"
  fi
fi

# verify all --cleanup-chart-resource chart names exist in --chart list
if _can_install_charts && [ "${#_var_chart_cleanup_chart_names[@]}" -gt 0 ] ; then
  log_verbose "Ensuring all charts set to --cleanup-chart-resource exist in --chart list"
  _found=()
  _excess=()
  for icn in "${_var_chart_cleanup_chart_names[@]}"
  do
    for cn in "${_var_chart_names[@]}"
    do
      if [[ "${cn}" == "${icn}" ]]; then
        _found+=("${icn}")
        continue 2
      fi
    done
    _excess+=("${icn}")
  done

  if [ "${#_excess[@]}" -gt 0 ]; then
    log_err "There are chart names present in the --cleanup-chart-resource list not found in --chart args: ${_excess[*]}"
    log_err "  --chart names                  : ${_var_chart_names[*]}"
    log_err "  --cleanup-chart-resource names : ${_var_chart_cleanup_chart_names[*]}"
    exit_error "Please either correct name provided to --cleanup-chart-resource or ensure all charts are present in a --chart arg"
  fi
fi

# verify all --apply-manifest filepaths exist in --manifest list
if _can_apply_manifests && [ "${#_var_apply_manifest_filepaths[@]}" -gt 0 ]; then
  log_verbose "Ensuring all manifest filepaths set to --apply-manifest exist in --manifest list"
  _found=()
  _excess=()
  for imfp in "${_var_apply_manifest_filepaths[@]}"
  do
    for mfp in "${_var_manifest_filepaths[@]}"
    do
      if [[ "${imfp}" == "${mfp}" ]]; then
        _found+=("${imfp}")
        continue 2
      fi
    done
    _excess+=("${imfp}")
  done

  if [ "${#_excess[@]}" -gt 0 ]; then
    log_err "There are manifest filepaths present in the --apply-manifest list not found in --manifest args: ${_excess[*]}]}"
    log_err "  --manifest filepaths       : ${_var_manifest_filepaths[*]}"
    log_err "  --apply-manifest filepaths : ${_var_apply_manifest_filepaths[*]}"
    exit_error "Please either correct filepaths provided to --apply-manifest or ensure all manifests are present in a --manifest arg"
  fi
fi


### Let the work begin.

# first, update local kubeconfig
if _can_update_kubeconfig ; then
  _exec_update_kubeconfig "${_var_aws_region}" "${_var_eks_cluster_name}"
  _exec_switch_kubectl_context "${_var_eks_cluster_name}"
else
  log_debug "Skipping kubeconfig update"
fi

# then, ensure all necessary namespaces exist
if _can_create_namespaces ; then
  for ns in "${_var_namespaces[@]}"
  do
    _exec_ensure_k8s_namespace_exists "${ns}"
  done
else
  log_debug "Skipping namespace creation"
fi

if _can_bootstrap_external_secrets ; then
  # install external-secrets chart

  if _exec_is_chart_installed "external-secrets" "default" ; then
    log_info "External secrets chart already installed"
  else
    _exec_helm_dep_update "external-secrets" "$(_get_chart_dir "external-secrets")"
    _exec_helm_install "external-secrets" "default" "$(_get_chart_dir "external-secrets")" "${_var_customer_name}"

    # wait for external-secrets controller pod to be "ok"
    _exec_wait_for_pod_ok "external-secrets-cert-controller" "default"
  fi

  # apply external secret manifests before installing any charts
  _exec_apply_manifests "external-secrets" "" 1
else
  log_debug "Skipping external secrets chart and manifest installation"
fi

# install charts
if _can_install_charts ; then

  # determine which list to use
  # TODO: this can almost assuredly be cleaned up...
  _charts_to_install=()
  if [ "${#_var_install_chart_names[@]}" -gt 0 ]; then
    _charts_to_install=("${_var_install_chart_names[@]}")
  elif [ "${#_var_chart_names[@]}" -gt 0 ]; then
    _charts_to_install=("${_var_chart_names[@]}")
  fi

  if [ "${#_charts_to_install[@]}" -gt 0 ]; then
    log_info "Installing" "${#_charts_to_install[@]}" "charts..."
    log_debug "Chart list:" "${_charts_to_install[*]}"

    # loop over specific list to install
    for install_me in "${_charts_to_install[@]}"
    do

      # loop over entire chart list
      for (( cni=0; cni < "${#_var_chart_names[@]}"; ++cni))
      do

        # get specific chart name
        cn="${_var_chart_names[$cni]}"

        # only install if chart is in the (potentially) limited list
        if [[ "${install_me}" == "${cn}" ]]; then

          # get chart details
          cns="${_var_chart_namespaces[$cni]}"
          clc="${_var_chart_lifecycles[$cni]}"
          cd="${_var_chart_directories[$cni]}"

          log_debug "Chart name: \"${cn}\""
          log_debug "Chart namespace: \"${cns}\""
          log_debug "Chart lifecycle: \"${clc}\""
          log_debug "Chart directory: \"${cd}\""

          # check if the chart has already been installed, and determine what should be done
          if _exec_is_chart_installed "${cn}" "${cns}"; then

            # if the chart is already installed in the k8s cluster, use lifecycle var to determine action

            log_info "Chart \"${cn}\" is already installed into namespace \"${cns}\""

            case "${clc}" in
              "${_LIFECYCLE_IGNORE}")
                # nothing to do here.
                ;;

              "${_LIFECYCLE_UPGRADE}")
                _exec_helm_dep_update "${cn}" "${cd}"
                _exec_helm_upgrade "${cn}" "${cns}" "${cd}" "${_var_customer_name}"
                ;;

              "${_LIFECYCLE_REINSTALL}")
                _exec_helm_uninstall "${cn}" "${cns}"
                _exec_chart_cleanup "${cn}"
                _exec_helm_dep_update "${cn}" "${cd}"
                _exec_helm_install "${cn}" "${cns}" "${cd}" "${_var_customer_name}"
                ;;

              *)
                log_err "Chart \"${cn}\" in namespace \"${cns}\" has unknown lifecycle value \"${clc}\""
                exit 1
                ;;
            esac

          else

            log_info "Chart \"${cn}\" is not currently installed into namespace \"${cns}\""

            # otherwise, attempt initial install
            _exec_helm_dep_update "${cn}" "${cd}"
            _exec_helm_install "${cn}" "${cns}" "${cd}" "${_var_customer_name}"

          fi

          # break out of this loop
          break
        fi
      done
    done
  fi
else
  log_debug "Skipping chart upgrade / installation"
fi

# apply manifests
if _can_apply_manifests ; then

  _manifests_filepaths_to_apply=()
  if [ "${#_var_apply_manifest_filepaths[@]}" -gt 0 ]; then
    _manifests_filepaths_to_apply=("${_var_apply_manifest_filepaths[@]}")
  elif [ "${#_var_manifest_filepaths[@]}" -gt 0 ]; then
    _manifests_filepaths_to_apply=("${_var_manifest_filepaths[@]}")
  fi

  if [ "${#_manifests_filepaths_to_apply[@]}" -gt 0 ]; then
    log_info "Applying" "${#_var_manifest_filepaths[@]}" "resource manifests..."
    log_debug "Manifest list:" "${_manifests_filepaths_to_apply[*]}"

    for (( mfpi=0; mfpi < "${#_var_manifest_filepaths[@]}"; ++mfpi ))
    do

      # get specific manifest filepath
      mfp="${_var_manifest_filepaths[$mfpi]}"

      # loop over specific list to apply
      for install_me in "${_manifests_filepaths_to_apply[@]}"
      do

        # check if this manifest is in the install list
        if [[ "${install_me}" == "${mfp}" ]]; then

          # get manifest details
          mns="${_var_manifest_namespaces[$mfpi]}"

          log_debug "Manifest filepath:" "${mfp}"
          log_debug "Manifest namespace:" "${mns}"

          _exec_apply_manifests "${mfp}" "${mns}" 1

        else
          log_debug "Skipping manifest ${mfp}"
        fi
      done
    done

  fi
else
  log_debug "Skipping resource manifest application"
fi
