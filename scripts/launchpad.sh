#!/bin/bash

# capture the current path
export TF_VAR_rover_version="$(echo $(cat /tf/rover/version.txt))"
current_path=$(pwd)
landingzone_name=$1
tf_action=$2
shift 2

export TF_VAR_workspace="level0"
export caf_command="launchpad"


while (( "$#" )); do
        case "$1" in
        -o|--output)
                tf_output_file=$2
                shift 2
                ;;
        *) # preserve positional arguments
                echo "else $1"

                PARAMS+="$1 "
                shift
                ;;
        esac
done

tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')

echo ""
echo "Launchpad management tool started with:"
echo "  tool        is : '$(echo ${caf_command})'"
echo "  tf_action   is : '$(echo ${tf_action})'"
echo "  tf_command  is : '$(echo ${tf_command})'"
echo "  landingzone is : '$(echo ${landingzone_name})'"
echo "  workspace   is : '$(echo ${TF_VAR_workspace})'"
echo ""


set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

source /tf/rover/functions.sh
source /tf/rover/banner.sh

verify_azure_session



# Trying to retrieve the terraform state storage account id
id=$(az storage account list --query "[?tags.tfstate=='level0' && tags.workspace=='level0']" -o json | jq -r .[0].id)

# Cannot execute the launchpad 

function launchpad_opensource {

        case "${id}" in 
                "null")
                        echo "No launchpad found."
                        rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}"

                        if [ "${tf_action}" == "destroy" ]; then
                                echo "There is no launchpad in this subscription"
                        else
                                echo "Deploying from scratch the launchpad"
                                initialize_state
                        fi
                        ;;
                '')
                        error ${LINENO} "you must login to an Azure subscription first or logout / login again" 2
                        ;;
                *)
                        
                        if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename ${landingzone_name}).tfstate" ]; then
                                echo "Recover from an un-finished initialisation"
                                if [ "${tf_action}" == "destroy" ]; then
                                        destroy
                                else
                                        initialize_state
                                fi
                                exit 0
                        else
                                case "${tf_action}" in
                                        "destroy")
                                                destroy_from_remote_state
                                                ;;
                                        "plan"|"apply")
                                                deploy_from_remote_state
                                                ;;
                                        *)
                                                get_launchpad_coordinates
                                                display_instructions
                                                ;;
                                esac
                        fi
                        ;;
        esac


}

function landing_zone {
        case "${tf_action}" in 
                "list")
                        echo "Listing the deployed landing zones"
                        list_deployed_landingzones
                        ;;
                *)
                        echo "launchpad landing_zone [ list | unlock [landing_zone_tfstate_name]]"
                        ;;
        esac
}

## Workspaces are used to isolate environments like sandpit, dev, sit, production
function workspace {

        if [ "${id}" == "null" ]; then
                display_launchpad_instructions
                exit 1000
        fi

        case "${tf_action}" in 
                "list")
                        workspace_list
                        ;;
                "create")
                        workspace_create ${tf_command}
                        ;;
                "delete")     
                        ;;
                *)
                        echo "launchpad workspace [ list | create | delete ]"
                        ;;
        esac
}

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
                        get_launchpad_coordinates
                        display_instructions
                fi
                ;;
        *)
                launchpad_opensource "level0"
esac

clean_up_variables