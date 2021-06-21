#!/bin/bash

# Initialize the launchpad first with rover
# deploy a landingzone with
# rover -lz [landingzone_folder_name] -a [plan | apply | destroy] [parameters]

source /tf/rover/lib/logger.sh
source /tf/rover/clone.sh
source /tf/rover/walkthrough.sh
source /tf/rover/tfstate_azurerm.sh
source /tf/rover/functions.sh
source /tf/rover/banner.sh

# symphony
source /tf/rover/ci.sh
source /tf/rover/cd.sh
source /tf/rover/symphony_yaml.sh
source /tf/rover/test_runner.sh

export ROVER_RUNNER=${ROVER_RUNNER:=false}

verify_rover_version

export TF_VAR_workspace=${TF_VAR_workspace:="tfstate"}
export TF_VAR_environment=${TF_VAR_environment:="sandpit"}
export TF_VAR_rover_version=$(echo $(cat /tf/rover/version.txt))
export TF_VAR_level=${TF_VAR_level:="level0"}
export TF_DATA_DIR=${TF_DATA_DIR:=$(echo ~)}
export ARM_SNAPSHOT=${ARM_SNAPSHOT:="true"}
export ARM_STORAGE_USE_AZUREAD=${ARM_STORAGE_USE_AZUREAD:="true"}
export impersonate=${impersonate:=false}
export skip_permission_check=${skip_permission_check:=false}
export symphony_run_all_tasks=true
export debug_mode=${debug_mode:="false"}
export devops=${devops:="false"}
export log_folder_path=${log_folderpath:="~/caflogs/logs"}

unset PARAMS

current_path=$(pwd)

mkdir -p ${TF_PLUGIN_CACHE_DIR}
__log_init__

while (( "$#" )); do
    case "${1}" in
        --walkthrough)
            export caf_command="walkthrough"
            shift 1
            ;;
        --clone|--clone-branch|--clone-folder|--clone-destination|--clone-folder-strip)
            export caf_command="clone"
            process_clone_parameter $@
            shift 2
            ;;
        -lz|--landingzone)
            export caf_command="landingzone"
            export landingzone_name=${2}
            export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename ${landingzone_name}).tfstate"}
            shift 2
            ;;
        -lp|--log-path)
            export log_folder_path=${2}
            shift 2
            ;;
        -c|--cloud)
            export cloud_name=${2}
            shift 2
            ;;
        -d|--debug)
            export debug_mode="true"
            set_log_degree DEBUG
            shift 1
            ;;
        --log-degree)
            set_log_degree $2
            shift 2    
            ;;      
        -a|--action)
            export tf_action=${2}
            shift 2
            ;;
        --clone-launchpad)
            export caf_command="clone"
            export landingzone_branch=${landingzone_branch:="master"}
            export clone_launchpad="true"
            export clone_landingzone="false"
            echo "cloning launchpad"
            shift 1
            ;;
        workspace)
            shift 1
            export caf_command="workspace"
            ;;
        landingzone)
            shift 1
            export caf_command="landingzone_mgmt"
            ;;
        login)
            shift 1
            export caf_command="login"
            ;;
        validate | ci)
            shift 1
            export caf_command="ci"
            export devops="true"
            ;;
        deploy | cd)
            export cd_action=${2}
            export TF_VAR_level="all"
            export caf_command="cd"
            export devops="true"       
            len=$#
            if [ "$len" == "1" ]; then
              shift 1
            else
              shift 2
            fi
            
            ;;            
        test)
            shift 1
            export caf_command="test"
            export devops="true"
            ;;            
        -sc|--symphony-config)
            export symphony_yaml_file=${2}
            shift 2
            ;;
        -ct|--ci-task-name)
            export ci_task_name=${2}
            export symphony_run_all_tasks=false
            shift 2
            ;;
        -b|--base-dir)
            export base_directory=${2}
            shift 2
            ;;
        -tfc|--tfc)
            shift 1
            export caf_command="tfc"
            ;;
        -t|--tenant)
            export tenant=${2}
            shift 2
            ;;
        -s|--subscription)
            export subscription=${2}
            shift 2
            ;;
        logout)
            shift 1
            export caf_command="logout"
            ;;
        -tfstate)
                export TF_VAR_tf_name=${2}
                if [ ${TF_VAR_tf_name##*.} != "tfstate" ]; then
                    echo "tfstate name extension must be .tfstate"
                    exit 50
                fi
                export TF_VAR_tf_plan="${TF_VAR_tf_name%.*}.tfplan"
                shift 2
                ;;
        -env|--environment)
                export TF_VAR_environment=${2}
                shift 2
                ;;
        -launchpad)
                export caf_command="launchpad"
                shift 1
                ;;
        -o|--output)
                tf_output_file=${2}
                shift 2
                ;;
        -p|--plan)
                tf_output_plan_file=${2}
                shift 2
                ;;
        -w|--workspace)
                export TF_VAR_workspace=${2}
                shift 2
                ;;
        -l|-level)
                export TF_VAR_level=${2}
                shift 2
                ;;
        --impersonate)
                export impersonate=true
                shift 1
                ;;
        -skip-permission-check)
                export skip_permission_check=true
                shift 1
                ;;
        -var-folder)
                expand_tfvars_folder ${2}
                shift 2
                ;;
        -tfstate_subscription_id)
                export TF_VAR_tfstate_subscription_id=${2}
                shift 2
                ;;
        -target_subscription)
                export target_subscription=${2}
                shift 2
                ;;

        *) # preserve positional arguments
                PARAMS+="${1} "
                shift
                ;;
        esac
done

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')


verify_azure_session
process_target_subscription

echo ""
echo "mode                          : '$(echo ${caf_command})'"

if [ ${caf_command} != "walkthrough" ]; then
  echo "terraform command output file : '$(echo ${tf_output_file})'"
  echo "terraform plan output file    : '$(echo ${tf_output_plan_file})'"
  echo "tf_action                     : '$(echo ${tf_action})'"
  echo "command and parameters        : '$(echo ${tf_command})'"
  echo ""
  echo "level (current)               : '$(echo ${TF_VAR_level})'"
  echo "environment                   : '$(echo ${TF_VAR_environment})'"
  echo "workspace                     : '$(echo ${TF_VAR_workspace})'"
  echo "tfstate                       : '$(echo ${TF_VAR_tf_name})'"
  echo "tfstate subscription id       : '$(echo ${TF_VAR_tfstate_subscription_id})'"
  echo "target subscription           : '$(echo ${target_subscription_name})'"
  echo "CI/CD enabled                 : '$(echo ${devops})'"
  echo "Symphony Yaml file path       : '$(echo ${symphony_yaml_file})'"
  echo "Run all tasks                 : '$(echo ${symphony_run_all_tasks})'"
fi
if [ $symphony_run_all_tasks == false ]; then
  echo "Running task                  : '$(echo ${ci_task_name})'"
fi
echo ""

export terraform_version=$(terraform --version | head -1 | cut -d ' ' -f 2)

process_actions
