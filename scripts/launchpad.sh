#!/bin/bash

source ./functions.sh

# Initialize the launchpad first with rover
# deploy a landingzone with 
# rover [landingzone_folder_name]

# capture the current path
current_path=$(pwd)
landingzone_name=$1
tf_action=$2
shift 2

tf_command=$@

echo "tf_action   is : '$(echo ${tf_action})'"
echo "tf_command  is : '$(echo ${tf_command})'"
echo "landingzone is : '$(echo ${landingzone_name})'"


verify_azure_session
verify_landingzone
verify_parameters

set -e
trap 'error ${LINENO}' ERR

export TF_PLUGIN_CACHE_DIR="/root/.terraform.d/plugin-cache"

# Trying to retrieve the terraform state storage account id
id=$(az resource list --tag stgtfstate=level0 | jq -r .[0].id)

if [ "${id}" == '' ]; then
        error ${LINENO} "you must login to an Azure subscription first or logout / login again" 2
fi

# Initialise storage account to store remote terraform state
if [ "${id}" == "null" ]; then
        echo "Calling initialize_state"
        landingzone_name="level0/launchpad_opensource"
else    
        echo ""
        echo "Launchpad already installed"
        get_remote_state_details
        echo ""
fi

if [ "${landingzone_name}" == "level0/launchpad_opensource" ]; then

        if [ "${tf_action}" == "destroy" ]; then
                echo "The launchpad is protected from deletion"
        else
                echo "Launchpad not installed"
                initialize_state

                id=$(az resource list --tag stgtfstate=level0 | jq -r .[0].id)

                echo "Launchpad installed and ready"
                display_instructions
                get_remote_state_details
        fi
else
        if [ -z "${landingzone_name}" ]; then 
                display_instructions
        else
                deploy_landingzone
        fi
fi
