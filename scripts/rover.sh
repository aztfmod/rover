#!/bin/bash


# Initialize the launchpad first with rover
# deploy a landingzone with 
# rover -lz [landingzone_folder_name] -a [plan | apply | destroy] [parameters]

source /tf/rover/clone.sh
source /tf/rover/functions.sh
source /tf/rover/banner.sh

export TF_VAR_workspace=${TF_VAR_workspace:="sandpit"}
export TF_VAR_environment=${TF_VAR_environment:="sandpit"}
export TF_VAR_rover_version=$(echo $(cat /tf/rover/version.txt))
export TF_VAR_level=${TF_VAR_level:="level0"}
export TF_DATA_DIR=${TF_DATA_DIR:="/home/vscode"}
export LC_ALL=en_US.UTF-8

current_path=$(pwd)

while (( "$#" )); do
    case "${1}" in
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
                export TF_VAR_workspace="level0"
                shift 1
                ;;
        -o|--output)
                tf_output_file=${2}
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
echo "terraform command output file : '$(echo ${tf_output_file})'"
echo "tf_action                     : '$(echo ${tf_action})'"
echo "command and parameters        : '$(echo ${tf_command})'"
echo "level (current)               : '$(echo ${TF_VAR_level})'" 
echo "environment                   : '$(echo ${TF_VAR_environment})'"
echo "workspace                     : '$(echo ${TF_VAR_workspace})'"
echo "tfstate                       : '$(echo ${TF_VAR_tf_name})'"
echo ""

process_actions
