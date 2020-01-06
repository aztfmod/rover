error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    if [[ -n "$message" ]] ; then
        >&2 echo -e "\e[41mError on or near line ${parent_lineno}: ${message}; exiting with status ${code}\e[0m"
    else
        >&2 echo -e "\e[41mError on or near line ${parent_lineno}; exiting with status ${code}\e[0m"
    fi
    echo ""
    exit "${code}"
}

function display_login_instructions {
    echo ""
    echo "To login the rover to azure:"
    echo " rover login [subscription_id_to_target(optional)]"
    echo ""
    echo " rover logout"
    echo ""
    echo "To display the current azure session"
    echo " rover login "
    echo ""
}

function display_instructions {
    echo ""
    echo "You can deploy a landingzone with the rover by running rover [landingzone_folder_name] [plan|apply|destroy]"
    echo ""
    echo "List of the landingzones loaded in the rover:"
    for i in $(ls -d /tf/caf/landingzones/*); do echo ${i%%/}; done
    echo ""
}


function verify_parameters {
    # Must provide an action when the tf_command is set
    if [ -z "${tf_action}" ] && [ ! -z "${tf_command}" ]; then
        display_instructions
        error ${LINENO} "landingzone and action must be set" 11
    fi
}

# The rover stores the Azure sessions in a local rover/.azure subfolder
# This function verifies the rover has an opened azure session
function verify_azure_session {
    if [ "${landingzone_name}" == "login" ]; then
        echo ""
        echo "Checking existing Azure session"
        session=$(az account show)

        if [ "${tf_command}" != "login" ] && [ ! -z "${tf_command}" ]; then
            echo "Login to azure with tenant ${tf_command}"
            ret=$(az login --tenant ${tf_command} >/dev/null >&1)
        else
            ret=$(az login >/dev/null >&1)
        fi

        # the second parameter would be the subscription id to target
        if [ ! -z "${tf_action}" ]; then
            echo "Set default subscription to ${tf_action}"
            az account set -s ${tf_action}
        fi
        
        az account show
        exit
    fi

    if [ "${landingzone_name}" == "logout" ]; then
            echo "Closing Azure session"
            az logout
            echo "Azure session closed"
            exit
    fi

    echo "Checking existing Azure session"
    session=$(az account show >/dev/null 2>&1)
    if [ $? == 1 ]; then
            display_login_instructions
            error ${LINENO} "you must login to an Azure subscription first or 'rover login' again" 2
    fi

}

# Verifies the landingzone exist in the rover
function verify_landingzone {
    if [ -z "${landingzone_name}" ] && [ -z "${tf_action}" ] && [ -z "${tf_command}" ]; then
            echo "Defaulting to /tf/launchpads/launchpad_opensource"
    else
            echo "Verify the landingzone folder exist in the rover"
            readlink -f "${landingzone_name}"
            if [ $? -ne 0 ]; then
                    display_instructions
                    error ${LINENO} "landingzone does not exist" 12
            fi
    fi
}

function initialize_state {
    echo "Installing launchpad from ${landingzone_name}"
    cd ${landingzone_name}

    rm -f -- ~/.terraform.cache/terraform.tfstate
    rm -f -- ./terraform.tfstate

    # TODO: when transitioning to devops pipeline need to be adjuested
    # Get the looged in user ObjectID
    export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv)
    tf_name="$(basename $(pwd)).tfstate"

    terraform init \
        -reconfigure=true \
        -get-plugins=true \
        -upgrade=true

    terraform apply \
        -var "tf_name=${tf_name}" \
        -auto-approve

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
            -get-plugins=true \
            -upgrade=true \
            -backend-config storage_account_name=${storage_account_name} \
            -backend-config container_name=${container} \
            -backend-config access_key=${access_key} \
            -backend-config key=${tf_name}


    terraform apply \
        -var tf_name=${tf_name} \
        -refresh=true -auto-approve

    rm backend.azurerm.tf
    rm -f -- ~/.terraform.cache/terraform.tfstate
    cd "${current_path}"
}

function upload_tfstate {
    echo "Moving launchpad to the cloud"

    storage_account_name=$(terraform output storage_account_name)
    resource_group=$(terraform output resource_group)
    access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value)
    container=$(terraform output container)
    tf_name="$(basename $(pwd)).tfstate"

    # blobFileName=$(terraform output tfstate-blob-name)

    az storage blob upload -f terraform.tfstate \
            -c ${container} \
            -n ${tf_name} \
            --account-key ${access_key} \
            --account-name ${storage_account_name}

    rm -f -- ~/.terraform.cache/terraform.tfstate
}

function get_remote_state_details {
    echo ""
    echo "Getting launchpad coordinates:"
    stg=$(az storage account show --ids ${id})

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
    export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
    export access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value) && echo " - storage_key: retrieved"
    export container=$(echo ${stg}  | jq -r .tags.container) && echo " - container: ${container}"
    location=$(echo ${stg} | jq -r .location) && echo " - location: ${location}"
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

function validate {
    echo 'running terraform validate'
    terraform validate
    
    cd "${current_path}"
}

function destroy {
    echo 'running terraform destroy'
    terraform destroy ${tf_command} \
            -refresh=false
}

function other {
    echo "running terraform ${tf_action}"
    terraform ${tf_action} ${tf_command}
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
            -get-plugins=true \
            -upgrade=true \
            -backend-config storage_account_name=${storage_account_name} \
            -backend-config container_name=${container} \
            -backend-config access_key=${access_key} \
            -backend-config key=${tf_name}

    case "${tf_action}" in 
        "plan")
            echo "calling plan"
            plan
            ;;
        "apply")
            echo "calling plan and apply"
            plan
            apply
            ;;
        "validate")
            echo "calling validate"
            validate
            ;;
        "destroy")
            echo "calling destroy"
            destroy
            ;;
        *)
            other
            ;;
    esac

    echo "Deleting file $(basename $(pwd)).tfplan"
    rm -f -- "$(basename $(pwd)).tfplan"
    rm -f -- ~/.terraform.cache/terraform.tfstate

    cd "${current_path}"
}

