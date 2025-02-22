#!/bin/bash

# Initialize the launchpad first with rover
# deploy a landingzone with
# rover -lz [landingzone_folder_name] -a [plan | apply | destroy] [parameters]


export script_path=$(dirname "$BASH_SOURCE")

source ${script_path}/clone.sh
source ${script_path}/functions.sh
export TF_VAR_rover_version=$(get_rover_version)
source ${script_path}/banner.sh
source ${script_path}/lib/bootstrap.sh
source ${script_path}/lib/init.sh
source ${script_path}/lib/logger.sh
source ${script_path}/lib/parse_parameters.sh
source ${script_path}/parse_command.sh
source ${script_path}/remote.sh
source ${script_path}/tfstate.sh
source ${script_path}/walkthrough.sh


# test runner
source ${script_path}/test_runner.sh

export ROVER_RUNNER=${ROVER_RUNNER:=false}

export TF_VAR_workspace=${TF_VAR_workspace:="tfstate"}
export TF_VAR_environment=${TF_VAR_environment:="sandpit"}
export TF_VAR_level=${TF_VAR_level:="level0"}
export TF_CACHE_FOLDER=${TF_DATA_DIR:=$(echo ~)}
export ARM_SNAPSHOT=${ARM_SNAPSHOT:="true"}
export ARM_USE_AZUREAD=${ARM_USE_AZUREAD:="true"}
export ARM_STORAGE_USE_AZUREAD=${ARM_STORAGE_USE_AZUREAD:="true"}
export ARM_USE_MSAL=${ARM_USE_MSAL:="false"}
export skip_permission_check=${skip_permission_check:=false}
export debug_mode=${debug_mode:="false"}
export devops=${devops:="false"}
export log_folder_path=${log_folderpath:=~/.terraform.logs}
export TF_IN_AUTOMATION="true" #Overriden in logger if log-severity is passed in.
export TF_VAR_tf_cloud_organization=${TF_CLOUD_ORGANIZATION}
export TF_VAR_tf_cloud_hostname=${TF_CLOUD_HOSTNAME:="app.terraform.io"}
export REMOTE_credential_path_json=${REMOTE_credential_path_json:="$(echo ~)/.terraform.d/credentials.tfrc.json"}
export gitops_terraform_backend_type=${TF_VAR_backend_type:="azurerm"}
export gitops_agent_pool_name=${GITOPS_AGENT_POOL_NAME}
export gitops_number_runners=0  # 0 - auto-scale , or set the number of minimum runners
export backend_type_hybrid=${BACKEND_type_hybrid:=true}
export gitops_agent_pool_execution_mode=${GITOPS_AGENT_POOL_EXECUTION_MODE:="local"}
export TF_VAR_tenant_id=${ARM_TENANT_ID:=}
export TF_VAR_user_type=${TF_VAR_user_type:=ServicePrincipal} # assume Service Principal

unset PARAMS

current_path=$(pwd)

mkdir -p ${TF_PLUGIN_CACHE_DIR}
__log_init__
set_log_severity ERROR # Default Log Severity. This can be overriden via -log-severity or -d (shortcut for -log-severity DEBUG)

# Parse command line parameters
parse_parameters "$@"

checkout_module
verify_rover_version

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')

if [ "${caf_command}" == "landingzone" ]; then
    TF_DATA_DIR=$(setup_rover_job "${TF_CACHE_FOLDER}/${TF_VAR_environment}")
elif [ "${caf_command}" == "launchpad" ]; then
    TF_DATA_DIR+="/${TF_VAR_environment}"
fi

verify_azure_session

# Check command and parameters
case "${caf_command}" in
    launchpad|landingzone)
        if [[ ("${tf_action}" != "destroy") && !("${tf_action}" =~  ^state ) && (-z "${tf_command}") ]]; then
            error ${LINENO} "No parameters have been set in ${caf_command}." 1
        fi
        ;;
    *)
        ;;
esac

if [ ! -z "${sp_keyvault_url}" ]; then
    # Impersonate the rover under sp credentials from keyvault
    # created with caf azuread_service_principals object
    login_as_sp_from_keyvault_secrets
fi

process_target_subscription

information ""
information "mode                          : '$(echo ${caf_command})'"

if [ "${caf_command}" != "walkthrough" ]; then
  information "terraform command output file : '$(echo ${tf_output_file})'"
  information "terraform plan output file    : '$(echo ${tf_plan_file})'"
  information "directory cache               : '$(echo ${TF_DATA_DIR})'"
  information "tf_action                     : '$(echo ${tf_action})'"
  information "command and parameters        : '$(echo ${tf_command})'"
  information ""
  information "level (current)               : '$(echo ${TF_VAR_level})'"
  information "environment                   : '$(echo ${TF_VAR_environment})'"
  information "workspace                     : '$(echo ${TF_VAR_workspace})'"
  information "terraform backend type        : '$(echo ${gitops_terraform_backend_type})'"
  information "backend_type_hybrid           : '$(echo ${backend_type_hybrid})'"
  information "tfstate                       : '$(echo ${TF_VAR_tf_name})'"
    if ${backend_type_hybrid} ; then
  information "tfstate subscription id       : '$(echo ${TF_VAR_tfstate_subscription_id})'"
  information "target subscription           : '$(echo ${target_subscription_name})'"
    fi
  information "Tenant id                     : '$(echo ${TF_VAR_tenant_id})'"
  information "CI/CD enabled                 : '$(echo ${devops})'"
  information "Run all tasks                 : 'true'"

  if [ ! -z "$TF_LOG" ]; then
    information "TF_LOG                        : '$(echo ${TF_LOG})'"
  fi
  if [ ! -z "$TF_IN_AUTOMATION" ]; then
    information "TF_IN_AUTOMATION              : '$(echo ${TF_IN_AUTOMATION})'"
  fi
fi

if [ ! -z "$ci_task_name" ]; then
  information "Running task                  : '$(echo ${ci_task_name})'"
fi
information ""


export terraform_version=$(terraform --version | head -1 | cut -d ' ' -f 2)

# set az cli extension context
az config set extension.use_dynamic_install=yes_without_prompt 2>/dev/null

process_actions
clean_up_variables

exit ${RETURN_CODE}
