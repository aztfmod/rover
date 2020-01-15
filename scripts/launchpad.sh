#!/bin/bash

source /tf/rover/functions.sh

# Initialize the launchpad first with rover
# deploy a landingzone with 
# rover [landingzone_folder_name]

# capture the current path
current_path=$(pwd)
landingzone_name=$1
tf_action=$2
shift 2

tf_command=$@
echo "Launchpad management tool started with:"
echo "  tf_action   is : '$(echo ${tf_action})'"
echo "  tf_command  is : '$(echo ${tf_command})'"
echo "  landingzone is : '$(echo ${landingzone_name})'"
echo ""

verify_azure_session
# verify_parameters

set -e
trap 'error ${LINENO}' ERR

# Trying to retrieve the terraform state storage account id
id=$(az resource list --tag stgtfstate=level0 | jq -r .[0].id)


if [ "${landingzone_name}" == "/tf/launchpads/launchpad_opensource" ]; then

        if [ -e "${TF_DATA_DIR}/tfstates/$(basename ${landingzone_name}).tfstate" ]; then
                echo "Recover from an un-finished initialisation"
                initialize_state
                exit 0
        else
                echo "Deploying from scratch the launchpad"
        
                if [ "${id}" == '' ]; then
                        error ${LINENO} "you must login to an Azure subscription first or logout / login again" 2
                fi
        fi

        if [ "${id}" == "null" ]; then
                initialize_state
        else
                
                if [ "${tf_action}" == "destroy" ]; then
                        destroy_from_remote_state
                else
                        initialize_from_remote_state
                fi
        fi
else
        case "${tf_command}" in 
                "list")
                        echo "Listing the deployed landing zones"
                        list_deployed_landingzones
                        ;;
                *)
                        display_launchpad_instructions
                        ;;
        esac
        
fi


