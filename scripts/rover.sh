#!/bin/bash


# Initialize the launchpad first with rover
# deploy a landingzone with 
# rover [landingzone_folder_name] [plan | apply | destroy] [parameters]

while (( "$#" )); do
        case "${1}" in
        --clone-launchpad)
                export landingzone_branch=${landingzone_branch:="master"}
                export clone_launchpad="true"
                export clone_landingzone="false"
                echo "cloning launchpad"
                shift 1
                ;;
        --clone-landingzones)
                export landingzone_branch=${landingzone_branch:="master"}
                export clone_landingzone="true"
                export clone_launchpad="false"
                echo "cloning landingzone"
                shift 1
                ;;
        --clone-branch)
                export landingzone_branch=${2}
                echo "cloning branch ${landingzone_branch}"
                shift 2
                ;;
        *)
                break
                ;;
        esac
done

source /tf/rover/functions.sh
source /tf/rover/banner.sh

verify_clone_repository

current_path=$(pwd)
landingzone_name=$1
tf_action=$2
shift 2

cd ${landingzone_name}

export TF_VAR_workspace=${TF_VAR_workspace:="sandpit"}
export TF_VAR_environment=${TF_VAR_environment:="sandpit"}
export TF_VAR_rover_version=$(echo $(cat /tf/rover/version.txt))
export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
export TF_VAR_level=${TF_VAR_level:="level0"}
export caf_command="rover"


while (( "$#" )); do
        case "${1}" in
        -o|--output)
                tf_output_file=${2}
                shift 2
                ;;
        -w|--workspace)
                export TF_VAR_workspace=${2}
                shift 2
                echo "set workspace to ${TF_VAR_workspace}"
                ;;
        -env|--environment)
                export TF_VAR_environment=${2}
                shift 2
                ;;
        -tfstate)
                export TF_VAR_tf_name="${2}.tfstate"
                export TF_VAR_tf_plan="${2}.tfplan"
                shift 2
                ;;
        -level)
                export TF_VAR_level=${2}
                shift 2
                ;;
        -launchpad)
                export caf_command="launchpad"
                export TF_VAR_workspace="level0"
                shift 1
                echo "set rover to mode ${caf_command}"
                echo "set workspace to level0"
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

echo ""

echo "mode                          : '$(echo ${caf_command})'"
echo "tf_action                     : '$(echo ${tf_action})'"
echo "tf_command                    : '$(echo ${tf_command})'"
echo "landingzone                   : '$(echo ${landingzone_name})'"
echo "terraform command output file : '$(echo ${tf_output_file})' "
echo "level (current)               : '$(echo ${TF_VAR_level})'" 
echo "environment                   : '$(echo ${TF_VAR_environment})'"
# echo "workspace                     : '$(echo ${TF_VAR_workspace})'"
echo "tfstate                       : '$(echo ${TF_VAR_tf_name})'"
echo ""

verify_azure_session
verify_parameters

cd ${landingzone_name}

# Trying to retrieve the terraform state storage account id
get_storage_id

case "${landingzone_name}" in
  "landing_zone")
    landing_zone
    ;;
  "workspace")
    workspace
    ;;
  "")
    if [ "${id}" == "null" ]; then
      display_launchpad_instructions
      exit 1000
    else
      # login_as_launchpad
      # get_launchpad_coordinates
      display_instructions
    fi
    ;;
  *)
    deploy ${TF_VAR_workspace}
esac