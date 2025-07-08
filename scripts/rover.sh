#!/bin/bash

#
# Azure Terraform SRE - Rover
# Main entry point and orchestration script for Terraform deployments on Azure
#
# Description:
#   Rover is a comprehensive toolset for managing enterprise Terraform deployments
#   on Microsoft Azure. It provides state management, CI/CD integration, and 
#   enterprise-grade features for Azure infrastructure deployments.
#
# Usage:
#   rover [COMMAND] [OPTIONS]
#   
#   Common commands:
#     rover login                                     # Authenticate to Azure
#     rover -lz <path> -a plan -env <env>            # Run Terraform plan
#     rover -lz <path> -a apply -env <env>           # Deploy infrastructure
#     rover -lz <path> -a destroy -env <env>         # Destroy infrastructure
#     rover ci -sc <symphony.yml>                    # Run CI pipeline
#
# Examples:
#   # Deploy a launchpad (foundation)
#   rover -lz ./landingzones/launchpad -a apply -env production --launchpad
#
#   # Deploy application landing zone
#   rover -lz ./landingzones/app -a apply -env production -level level2
#
#   # Run continuous integration
#   rover ci -sc ./configs/symphony.yml -b ./
#
# Author: Azure CAF Team
# Repository: https://github.com/aztfmod/rover
# Documentation: https://github.com/aztfmod/rover/docs
#

# Get the directory path of this script for sourcing other components
export script_path=$(dirname "$BASH_SOURCE")

# Source core functionality modules
# Order matters - dependencies must be loaded first

# Core utility functions and helpers
source ${script_path}/functions.sh

# Get rover version for telemetry and compatibility checks
export TF_VAR_rover_version=$(get_rover_version)

# Load foundational components
source ${script_path}/clone.sh              # Repository cloning functionality
source ${script_path}/banner.sh             # CLI banner and branding
source ${script_path}/lib/bootstrap.sh      # Environment initialization
source ${script_path}/lib/init.sh           # Terraform initialization helpers
source ${script_path}/lib/logger.sh         # Logging and output management
source ${script_path}/lib/parse_parameters.sh # Parameter validation and parsing
source ${script_path}/parse_command.sh      # CLI command parsing
source ${script_path}/remote.sh             # Remote backend configuration
source ${script_path}/tfstate.sh            # Terraform state management
source ${script_path}/walkthrough.sh        # Interactive setup workflows

# CI/CD and automation components
source ${script_path}/ci.sh                 # Continuous integration workflows
# CI/CD and automation components
source ${script_path}/ci.sh                 # Continuous integration workflows
source ${script_path}/cd.sh                 # Continuous deployment workflows
source ${script_path}/symphony_yaml.sh      # Symphony configuration parsing
source ${script_path}/test_runner.sh        # Test execution framework

# Load Terraform Cloud integration components
for script in ${script_path}/tfcloud/*.sh; do
  source "$script"
done

#
# Default Environment Configuration
# These variables can be overridden via environment variables or command line parameters
#

# Rover runtime configuration
export ROVER_RUNNER=${ROVER_RUNNER:=false}              # Flag to indicate if running in agent mode

# Terraform workspace and environment defaults
export TF_VAR_workspace=${TF_VAR_workspace:="tfstate"}   # Default Terraform workspace name
export TF_VAR_environment=${TF_VAR_environment:="sandpit"} # Default environment (dev/staging/prod)
export TF_VAR_level=${TF_VAR_level:="level0"}            # Landing zone level (0-4)

# File system and caching configuration  
export TF_CACHE_FOLDER=${TF_DATA_DIR:=$(echo ~)}         # Terraform cache directory
export log_folder_path=${log_folderpath:=~/.terraform.logs} # Log file location

# Azure Resource Manager configuration
export ARM_SNAPSHOT=${ARM_SNAPSHOT:="true"}              # Enable ARM snapshots for state protection
export ARM_USE_AZUREAD=${ARM_USE_AZUREAD:="true"}        # Use Azure AD authentication
export ARM_STORAGE_USE_AZUREAD=${ARM_STORAGE_USE_AZUREAD:="true"} # Use Azure AD for storage
export ARM_USE_MSAL=${ARM_USE_MSAL:="false"}            # Use Microsoft Authentication Library

# Security and validation settings
export skip_permission_check=${skip_permission_check:=false} # Skip Azure permission validation

# CI/CD pipeline configuration
export symphony_run_all_tasks=true                       # Run all symphony tasks by default
export debug_mode=${debug_mode:="false"}                # Debug logging mode
export devops=${devops:="false"}                        # DevOps integration mode
export TF_IN_AUTOMATION="true"                          # Indicate automated execution (overridden by logger)

# Terraform Cloud/Enterprise configuration
export TF_VAR_tf_cloud_organization=${TF_CLOUD_ORGANIZATION}     # TFC organization name
export TF_VAR_tf_cloud_hostname=${TF_CLOUD_HOSTNAME:="app.terraform.io"} # TFC hostname
export REMOTE_credential_path_json=${REMOTE_credential_path_json:="$(echo ~)/.terraform.d/credentials.tfrc.json"}

# GitOps and agent configuration
export gitops_terraform_backend_type=${TF_VAR_backend_type:="azurerm"}  # Backend type for GitOps
export gitops_agent_pool_name=${GITOPS_AGENT_POOL_NAME}  # Agent pool name for GitOps
export gitops_number_runners=0                           # Number of runners (0 = auto-scale)
export backend_type_hybrid=${BACKEND_type_hybrid:=true}  # Enable hybrid backend support
export gitops_agent_pool_execution_mode=${GITOPS_AGENT_POOL_EXECUTION_MODE:="local"} # Execution mode

# Azure authentication context
export TF_VAR_tenant_id=${ARM_TENANT_ID:=}              # Azure tenant ID
export TF_VAR_user_type=${TF_VAR_user_type:=ServicePrincipal} # Authentication type (assume SP)

# Clear parameter collection variable
unset PARAMS

# Store current working directory for context
current_path=$(pwd)

#
# Initialize Rover Environment
#

# Create Terraform plugin cache directory
mkdir -p ${TF_PLUGIN_CACHE_DIR}

# Initialize logging subsystem
__log_init__

# Set default log severity (can be overridden by --log-severity or -d flags)
set_log_severity ERROR

#
# Main Execution Flow
#

# Parse and validate command line parameters
parse_parameters "$@"

# Checkout and validate rover modules
checkout_module
verify_rover_version

# Set error handling and trapping
# -E: inherit ERR trap in functions, command substitutions, and subshells
# -T: inherit DEBUG and RETURN traps 
# -e: exit immediately on command failure
set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

# Process the terraform command string from parsed parameters
tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')

#
# Setup Working Directory Based on Command Type
#
if [ "${caf_command}" == "landingzone" ]; then
    # For landing zone deployments, create environment-specific directory
    TF_DATA_DIR=$(setup_rover_job "${TF_CACHE_FOLDER}/${TF_VAR_environment}")
elif [ "${caf_command}" == "launchpad" ]; then
    # For launchpad deployments, use environment subdirectory
    TF_DATA_DIR+="/${TF_VAR_environment}"
fi

# Verify Azure authentication is valid before proceeding
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
  information "Symphony Yaml file path       : '$(echo ${symphony_yaml_file})'"
  information "Run all tasks                 : '$(echo ${symphony_run_all_tasks})'"

  if [ ! -z "$TF_LOG" ]; then
    information "TF_LOG                        : '$(echo ${TF_LOG})'"
  fi
  if [ ! -z "$TF_IN_AUTOMATION" ]; then
    information "TF_IN_AUTOMATION              : '$(echo ${TF_IN_AUTOMATION})'"
  fi
fi

if [ $symphony_run_all_tasks == false ]; then
  information "Running task                  : '$(echo ${ci_task_name})'"
fi
information ""


export terraform_version=$(terraform --version | head -1 | cut -d ' ' -f 2)

# set az cli extension context
az config set extension.use_dynamic_install=yes_without_prompt 2>/dev/null

process_actions
clean_up_variables

exit ${RETURN_CODE}
