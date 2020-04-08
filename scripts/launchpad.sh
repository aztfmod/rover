#!/bin/bash

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

source /tf/rover/functions.sh


# capture the current path
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
        -w|--workspace)
                export TF_VAR_workspace=$2
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

echo "Launchpad management tool started with:"
echo "  tf_action   is : '$(echo ${tf_action})'"
echo "  tf_command  is : '$(echo ${tf_command})'"
echo "  landingzone is : '$(echo ${landingzone_name})'"
echo "  workspace   is : '$(echo ${TF_VAR_workspace})'"
echo ""

verify_azure_session



# Trying to retrieve the terraform state storage account id
id=$(az storage account list --query "[?tags.tfstate=='level0']" | jq -r .[0].id)

# Cannot execute the launchpad 

function launchpad_opensource {

        case "${id}" in 
                "null")
                        echo "No launchpad found."
                        rm  "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/*"
                        
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
                                echo "Deploying from the launchpad"
                                if [ "${tf_action}" == "destroy" ]; then
                                        destroy_from_remote_state
                                else
                                        deploy_from_remote_state
                                fi
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
        "/tf/launchpads/launchpad_opensource")
                launchpad_opensource "level0"
                ;;
        "/tf/launchpads/launchpad_opensource_light")
                launchpad_opensource "level0"
                ;;
        "landing_zone")
                landing_zone
                ;;
        "workspace")
                workspace
                ;;
        *)
                if [ "${id}" == "null" ]; then
                        display_launchpad_instructions
                        exit 1000
                else
                        verify_landingzone
                fi
                ;;
esac

clean_up_variables