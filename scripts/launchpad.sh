#!/bin/bash

# Initialize the launchpad first with ./launchpad.sh
# deploy a landingzone with ./launchpad.sh [landingzone_folder_name]

# capture the current path
current_path=$(pwd)
landingzone_name=$1
tf_action=$2
shift 2

tf_command=$@

echo "tf_action   is : '$(echo ${tf_action})'"
echo "tf_command  is : '$(echo ${tf_command})'"
echo "landingzone is : '$(echo ${landingzone_name})'"

error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    >&2 echo -e "\e[41mError on or near line ${parent_lineno}: ${message}; exiting with status ${code}\e[0m"
  else
    >&2 echo -e "\e[41mError on or near line ${parent_lineno}; exiting with status ${code}\e[0m"
  fi
  exit "${code}"
}

function display_instructions {
        echo ""
        echo "You can deploy a landingzone with the rover by running ./rover.sh [landingzone_folder_name] [plan|apply|destroy]"
        echo ""
        echo "List of the landingzones loaded in the rover:"
        for i in $(ls -d landingzones/landingzone*); do echo ${i%%/}; done
        echo ""
}

function verify_parameters {
        # Must provide an action when the tf_command is set
        if [ -z "${tf_action}" ] && [ ! -z "${tf_command}" ]; then
            display_instructions
            error ${LINENO} "landingzone and action must be set" 11
        fi
}

function verify_landingzone {
        if [ -z "${landingzone_name}" ] && [ -z "${tf_action}" ] && [ -z "${tf_command}" ]; then
                echo "Defaulting to level0/launchpad_opensource"
        else
                echo "Verify the landingzone folder exist in the rover"
                readlink -f "${landingzone_name}"
                if [ $? -ne 0 ]; then
                        display_instructions
                        error ${LINENO} "landingzone does not exist" 12
                fi
        fi
}

verify_landingzone
verify_parameters

set -e
trap 'error ${LINENO}' ERR

export TF_PLUGIN_CACHE_DIR="/root/.terraform.d/plugin-cache"

function initialize_state {
        echo "Installing launchpad from ${landingzone_name}"
        cd ${landingzone_name}
        set +e
        rm ./.terraform/terraform.tfstate
        rm ./terraform.tfstate
        rm backend.azurerm.tf
        set -e

        # Get the looged in user ObjectID
        export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv)

        terraform init
        terraform apply -auto-approve

        echo ""
        upload_tfstate

        cd "${current_path}"
}

function initialize_from_remote_state {
        echo 'Connecting to the launchpad'
        cd ${landingzone_name}
        cp backend.azurerm backend.azurerm.tf
        tf_name="$(basename $(pwd)).tfstate"

        terraform init \
                -backend=true \
                -reconfigure=true \
                -upgrade=true \
                -backend-config storage_account_name=${storage_account_name} \
                -backend-config container_name=${container} \
                -backend-config access_key=${access_key} \
                -backend-config key=${tf_name}


        terraform apply -refresh=true -auto-approve

        rm backend.azurerm.tf
        cd "${current_path}"
}

function plan {
        echo "running terraform plan with $tf_command"
        pwd
        terraform plan $tf_command \
                -refresh=true \
                -out="$(basename $(pwd)).tfplan"
}

function apply {
        echo 'running terraform apply'
        terraform apply \
                -no-color \
                "$(basename $(pwd)).tfplan"
        
        cd "${current_path}"
}

function destroy {
        echo 'running terraform destroy'
        terraform destroy ${tf_command} \
                -refresh=true
}


function deploy_landingzone {

        echo "Deploying '${landingzone_name}'"

        cd ${landingzone_name}

        tf_name="$(basename $(pwd)).tfstate"

        # Get parameters of the terraform state from keyvault. Note we are using tags to retrieve the level0
        export keyvault=$(az resource list --tag kvtfstate=level0 | jq -r .[0].name) && echo " - keyvault_name: ${keyvault}"

        # Set the security context under the devops app
        echo ""
        echo "Identity of the pilot in charge of delivering the landingzone"
        export ARM_SUBSCRIPTION_ID=$(az keyvault secret show -n tfstate-sp-devops-subscription-id --vault-name ${keyvault} | jq -r .value) && echo " - subscription id: ${ARM_SUBSCRIPTION_ID}"
        export ARM_CLIENT_ID=$(az keyvault secret show -n tfstate-sp-devops-client-id --vault-name ${keyvault} | jq -r .value) && echo " - client id: ${ARM_CLIENT_ID}"
        export ARM_CLIENT_SECRET=$(az keyvault secret show -n tfstate-sp-devops-client-secret --vault-name ${keyvault} | jq -r .value)
        export ARM_TENANT_ID=$(az keyvault secret show -n tfstate-sp-devops-tenant-id --vault-name ${keyvault} | jq -r .value) && echo " - tenant id: ${ARM_TENANT_ID}"
 
        export TF_VAR_prefix=$(az keyvault secret show -n tfstate-prefix --vault-name ${keyvault} | jq -r .value)
        echo ""
        export TF_VAR_lowerlevel_storage_account_name=$(az keyvault secret show -n tfstate-storage-account-name --vault-name ${keyvault} | jq -r .value)
        export TF_VAR_lowerlevel_resource_group_name=$(az keyvault secret show -n tfstate-resource-group --vault-name ${keyvault} | jq -r .value)
        export TF_VAR_lowerlevel_key=$(az keyvault secret show -n tfstate-blob-name --vault-name ${keyvault} | jq -r .value)
        export TF_VAR_lowerlevel_container_name=$(az keyvault secret show -n tfstate-container --vault-name ${keyvault} | jq -r .value)
        
        # todo to be replaced with SAS key - short ttl or msi with the rover
        export ARM_ACCESS_KEY=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value)

        terraform init \
                -reconfigure \
                -backend=true \
                -lock=false \
                -backend-config storage_account_name=${storage_account_name} \
                -backend-config container_name=${container} \
                -backend-config access_key=${access_key} \
                -backend-config key=${tf_name}

        if [ ${tf_action} == "plan" ]; then
                echo "calling plan"
                plan
        fi

        if [ ${tf_action} == "apply" ]; then
                echo "calling plan and apply"
                plan
                apply
        fi

        if [ ${tf_action} == "destroy" ]; then
                echo "calling destroy"
                destroy
        fi

        if [ -f "$(basename $(pwd)).tfplan" ]; then
                echo "Deleting file $(basename $(pwd)).tfplan"
                rm "$(basename $(pwd)).tfplan"
        fi

        cd "${current_path}"

}

function upload_tfstate {
        echo "Moving launchpad to the cloud"

        storage_account_name=$(terraform output storage_account_name)
        resource_group=$(terraform output resource_group)
        access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value)
        container=$(terraform output container)
        tf_name="$(basename $(pwd)).tfstate"

        blobFileName=$(terraform output tfstate-blob-name)

        az storage blob upload -f terraform.tfstate \
                -c ${container} \
                -n ${blobFileName} \
                --account-key ${access_key} \
                --account-name ${storage_account_name}

        rm -f terraform.tfstate

}

function get_remote_state_details {
        echo ""
        echo "Getting level0 launchpad coordinates:"
        stg=$(az storage account show --ids ${id})

        export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
        export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
        export access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value) && echo " - storage_key: retrieved"
        export container=$(echo ${stg}  | jq -r .tags.container) && echo " - container: ${container}"
        location=$(echo ${stg} | jq -r .location) && echo " - location: ${location}"
        export tf_name="$(basename $(pwd)).tfstate"
}


# Trying to retrieve the terraform state storage account id
id=$(az resource list --tag stgtfstate=level0 | jq -r .[0].id)

if [ "${id}" == '' ]; then
        error ${LINENO} "you must login to an Azure subscription first or logout / login again" 2
fi

# Initialise storage account to store remote terraform state
if [ "${id}" == "null" ]; then
        echo "Calling initialize_state"
        landingzone_name="level0_launchpad"

        initialize_state

        id=$(az resource list --tag stgtfstate=level0 | jq -r .[0].id)

        echo "Launchpad installed and ready"
        get_remote_state_details
else    
        echo ""
        echo "Launchpad already installed"
        get_remote_state_details
        echo ""
fi

if [ "${landingzone_name}" == "level0/level0_launchpad" ]; then

        if [ "${tf_action}" == "destroy" ]; then
                echo "The launchpad is protected from deletion"
        fi

        display_instructions
else
        if [ -z "${landingzone_name}" ]; then 
                display_instructions
        else
                deploy_landingzone
        fi
fi
