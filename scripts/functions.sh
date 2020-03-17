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

    clean_up_variables

    exit "${code}"
}

function display_login_instructions {
    echo ""
    echo "To login the rover to azure:"
    echo " rover login [tenant_name.onmicrosoft.com or tenant_guid (optional)] [subscription_id_to_target(optional)]"
    echo ""
    echo " rover logout"
    echo ""
    echo "To display the current azure session"
    echo " rover login "
    echo ""
}

function display_instructions {
    echo ""
    echo "You can deploy a landingzone with the rover by running:"
    echo "  rover [landingzone_folder_name] [plan|apply|destroy]"
    echo ""
    echo "List of the landingzones loaded in the rover:"

    if [ -d "/tf/caf/landingzones" ]; then
        for i in $(ls -d /tf/caf/landingzones/landingzone*); do echo ${i%%/}; done
        echo ""
    fi

    if [ -d "/tf/caf/landingzones/public" ]; then
        for i in $(ls -d /tf/caf/landingzones/public/landingzones/landingzone*); do echo ${i%%/}; done
            echo ""
    fi

    # The followinf folder is used when developing the launchpads from the rover.
    if [ -d "/tf/caf/launchpads" ]; then
        for i in $(ls -d /tf/caf/launchpads/launchpad*); do echo ${i%%/}; done
            echo ""
    fi
}

function display_launchpad_instructions {
    echo ""
    echo "You can bootstrap the launchpad from the rover by running:"
    echo " launchpad [launchpad_foler_name] [plan|apply|destroy]"
    echo ""
    echo "List of the launchpads available:"
    
    if [ -d "/tf/launchpads" ]; then
        for i in $(ls -d /tf/launchpads/launchpad*); do echo ${i%%/}; done
            echo ""
    fi
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

        if [ ! -z "${tf_action}" ]; then
            echo "Login to azure with tenant ${tf_action}"
            ret=$(az login --tenant ${tf_action} >/dev/null >&1)
        else
            ret=$(az login >/dev/null >&1)
        fi

        # the second parameter would be the subscription id to target
        if [ "${tf_command}" != "login" ] && [ ! -z "${tf_command}" ]; then
            echo "Set default subscription to ${tf_command}"
            az account set -s ${tf_command}
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
            get_remote_state_details

        if [ -z ${TF_VAR_lowerlevel_storage_account_name} ]; then 
            display_launchpad_instructions
        else
            display_instructions
        fi
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

    rm -f -- ${landingzone_name}/backend.azurerm.tf
    rm -f -- "${TF_DATA_DIR}/terraform.tfstate"

    # TODO: when transitioning to devops pipeline need to be adjuested
    # Get the looged in user ObjectID
    export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv)
    export TF_VAR_tf_name="$(basename $(pwd)).tfstate"

    terraform init \
        -get-plugins=true \
        -upgrade=true

    case "${tf_action}" in 
        "plan")
            echo "calling plan"
            plan
            ;;
        "apply")
            echo "calling plan and apply"
            plan
            apply
            # Create sandpit workspace
            id=$(az storage account list --query "[?tags.tfstate=='level0']" | jq -r .[0].id)
            workspace_create "sandpit"
            workspace_create ${TF_VAR_workspace}
            upload_tfstate
            ;;
        "validate")
            echo "calling validate"
            validate
            ;;
        "destroy")
            echo "Shall we call destroy here?"
            exit
            ;;
        *)
            other
            ;;
    esac

    cd "${current_path}"
}

function deploy_from_remote_state {
    echo 'Connecting to the launchpad'
    cd ${landingzone_name}

    if [ -f "backend.azurerm" ]; then
        cp backend.azurerm backend.azurerm.tf
    fi

    export logged_user_upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
    export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv) && echo " - logged in objectId: ${TF_VAR_logged_user_objectId} (${logged_user_upn})"
    export TF_VAR_tf_name="$(basename $(pwd)).tfstate"
   
    deploy_landingzone
    
    cd "${current_path}"
}

function destroy_from_remote_state {
    echo "Destroying from remote state"
    echo 'Connecting to the launchpad'
    cd ${landingzone_name}

    export logged_user_upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
    export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv) && echo " - logged in objectId: ${TF_VAR_logged_user_objectId} (${logged_user_upn})"

    get_remote_state_details
    tf_name="$(basename $(pwd)).tfstate"

    fileExists=$(az storage blob exists \
        --name ${tf_name} \
        --container-name ${TF_VAR_workspace} \
        --account-key ${ARM_ACCESS_KEY} \
        --account-name ${TF_VAR_lowerlevel_storage_account_name} | jq .exists)
    
    if [ ${fileExists} == true ]; then
        if [ ${TF_VAR_workspace} == "level0" ]; then
            az storage blob download \
                    --name ${tf_name} \
                    --file "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}" \
                    --container-name ${TF_VAR_workspace} \
                    --account-key ${ARM_ACCESS_KEY} \
                    --account-name ${TF_VAR_lowerlevel_storage_account_name} \
                    --no-progress

            destroy
        else
            destroy "remote"
        fi
    else
        echo "landing zone already deleted"
    fi

    cd "${current_path}"
}

function upload_tfstate {
    echo "Moving launchpad to the cloud"

    stg=$(az storage account show --ids ${id})

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
    export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
    export access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value) && echo " - storage_key: retrieved"

    az storage blob upload -f "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
            -c ${TF_VAR_workspace} \
            -n ${TF_VAR_tf_name} \
            --auth-mode key \
            --account-key ${access_key} \
            --account-name ${storage_account_name} \
            --no-progress

    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${TF_VAR_tf_name}"

    display_instructions
}

function list_deployed_landingzones {
    
    stg=$(az storage account show --ids ${id})

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
    export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
    export access_key=$(az storage account keys list --account-name ${storage_account_name} --resource-group ${resource_group} | jq -r .[0].value) && echo " - storage_key: retrieved"

    echo ""
    echo "Landing zones deployed:"
    echo ""

    az storage blob list \
            -c ${TF_VAR_workspace} \
            --account-key ${access_key} \
            --account-name ${storage_account_name} |  \
    jq -r '["lnanding zone", "size in Kb", "last modification"], (.[] | [.name, .properties.contentLength / 1024, .properties.lastModified]) | @csv' | \
    awk 'BEGIN{ FS=OFS="," }NR>1{ $2=sprintf("%.2f",$2) }1'  | \
    column -t -s ','

    echo ""
}

function get_remote_state_details {
    echo ""
    echo "Getting launchpad coordinates:"
    
    stg=$(az storage account show --ids ${id})

    export TF_VAR_lowerlevel_storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${TF_VAR_lowerlevel_storage_account_name}"
    export TF_VAR_lowerlevel_resource_group_name=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${TF_VAR_lowerlevel_resource_group_name}"

    # todo to be replaced with SAS key - short ttl or msi with the rover
    export ARM_ACCESS_KEY=$(az storage account keys list --account-name ${TF_VAR_lowerlevel_storage_account_name} --resource-group ${TF_VAR_lowerlevel_resource_group_name} | jq -r .[0].value)

    # Set the security context under the devops app
    export keyvault=$(az keyvault list --query "[?tags.tfstate=='level0']" | jq -r .[0].name) && echo " - keyvault_name: ${keyvault}"
    export TF_VAR_lowerlevel_container_name=$(az keyvault secret show -n launchpad-blob-container --vault-name ${keyvault} | jq -r .value) && echo " - container: ${TF_VAR_lowerlevel_container_name}"
    export TF_VAR_lowerlevel_key=$(az keyvault secret show -n launchpad-blob-name --vault-name ${keyvault} | jq -r .value) && echo " - tfstate file: ${TF_VAR_lowerlevel_key}"

    echo ""
    echo "Identity of the pilot in charge of delivering the landingzone"
    if [ "${TF_VAR_limited_privilege}" == "1" ]; then
        echo " - Name: ${TF_VAR_logged_user_objectId} (${logged_user_upn})"
    else
        export LAUNCHPAD_NAME=$(az keyvault secret show -n launchpad-name --vault-name ${keyvault} | jq -r .value) && echo " - Name: ${LAUNCHPAD_NAME}"
        export ARM_CLIENT_ID=$(az keyvault secret show -n launchpad-application-id --vault-name ${keyvault} | jq -r .value) && echo " - client id: ${ARM_CLIENT_ID}"
        export TF_VAR_rover_pilot_client_id=$(az keyvault secret show -n launchpad-service-principal-client-id --vault-name ${keyvault} | jq -r .value) && echo " - rover client id: ${TF_VAR_rover_pilot_client_id}"
        export ARM_CLIENT_SECRET=$(az keyvault secret show -n launchpad-service-principal-client-secret --vault-name ${keyvault} | jq -r .value)
    fi

    export ARM_TENANT_ID=$(az keyvault secret show -n launchpad-tenant-id --vault-name ${keyvault} | jq -r .value) && echo " - tenant id: ${ARM_TENANT_ID}"
    export ARM_SUBSCRIPTION_ID=$(az keyvault secret show -n launchpad-subscription-id --vault-name ${keyvault} | jq -r .value) && echo " - subscription id: ${ARM_SUBSCRIPTION_ID}"
    


    export TF_VAR_prefix=$(az keyvault secret show -n launchpad-prefix --vault-name ${keyvault} | jq -r .value)
    echo ""



}

function plan {
    echo "running terraform plan with $tf_command"
    pwd
    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}"

    terraform plan $tf_command \
            -refresh=true \
            -state="${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename $(pwd)).tfstate" \
            -out="${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename $(pwd)).tfplan" | tee ${tf_output_file}
}

function apply {
    echo 'running terraform apply'
    terraform apply \
            -state="${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename $(pwd)).tfstate" \
            -no-color \
            "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename $(pwd)).tfplan" | tee ${tf_output_file}
    
}

function validate {
    echo 'running terraform validate'
    terraform validate
    
}

function destroy {
    cd ${landingzone_name}
    
    tf_name="$(basename $(pwd)).tfstate"

    export TF_VAR_tf_name="$(basename $(pwd)).tfstate"

    rm -f "${TF_DATA_DIR}/terraform.tfstate"
    rm -f ${landingzone_name}/backend.azurerm.tf
    
    # get_remote_state_details

    if [ $1 == "remote" ]; then

        if [ -e backend.azurerm ]; then
            cp -f backend.azurerm backend.azurerm.tf
        fi

        echo 'running terraform destroy remote'
        terraform init \
            -reconfigure=true \
            -backend=true \
            -get-plugins=true \
            -upgrade=true \
            -backend-config storage_account_name=${TF_VAR_lowerlevel_storage_account_name} \
            -backend-config container_name=${TF_VAR_workspace} \
            -backend-config access_key=${ARM_ACCESS_KEY} \
            -backend-config key=${tf_name}

        terraform destroy ${tf_command}
    else
        echo 'running terraform destroy with local tfstate'
        # Destroy is performed with the logged in user who last ran the launchap .. apply from the rover. Only this user has permission in the kv access policy
        unset ARM_TENANT_ID
        unset ARM_SUBSCRIPTION_ID
        unset ARM_CLIENT_ID
        unset ARM_CLIENT_SECRET

        terraform init \
            -reconfigure=true \
            -get-plugins=true \
            -upgrade=true

        echo "using tfstate from ${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}"
        mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}"

        terraform destroy ${tf_command} \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}"

        echo "Removing ${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}"
        rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}"

    fi

    # Delete tfstate
    stgNameAvailable=$(az storage account check-name --name ${TF_VAR_lowerlevel_storage_account_name} | jq .nameAvailable)
    if [ ${stgNameAvailable} == false ]; then
        fileExists=$(az storage blob exists \
                --name ${tf_name} \
                --container-name ${TF_VAR_workspace} \
                --account-key ${ARM_ACCESS_KEY} \
                --account-name ${TF_VAR_lowerlevel_storage_account_name} | jq .exists)
        
        if [ ${fileExists} == true ]; then
            az storage blob delete \
                    --name ${tf_name} \
                    --container-name ${TF_VAR_workspace} \
                    --account-key ${ARM_ACCESS_KEY} \
                    --account-name ${TF_VAR_lowerlevel_storage_account_name}
        fi
    fi
}

function other {
    echo "running terraform ${tf_action}"
    terraform ${tf_action} ${tf_command} | tee ${tf_output_file}
}

function deploy_landingzone {
    echo "Deploying '${landingzone_name}'"

    cd ${landingzone_name}
    tf_name="$(basename $(pwd)).tfstate"

    get_remote_state_details

    terraform init \
            -reconfigure \
            -backend=true \
            -get-plugins=true \
            -upgrade=true \
            -backend-config storage_account_name=${TF_VAR_lowerlevel_storage_account_name} \
            -backend-config container_name=${TF_VAR_workspace} \
            -backend-config access_key=${ARM_ACCESS_KEY} \
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

    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/$(basename $(pwd)).tfplan"
    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}/${tf_name}"

    cd "${current_path}"
}


##### workspace functions

function workspace_list {

    echo " Calling workspace_list function"
    stg=$(az storage account show --ids ${id})

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Listing workspaces:"
    echo  ""
    az storage container list \
            --auth-mode "login" \
            --account-name ${storage_account_name} |  \
    jq -r '["workspace", "last modification", "lease ststus"], (.[] | [.name, .properties.lastModified, .properties.leaseStatus]) | @csv' | \
    column -t -s ','

    echo ""
}

function workspace_create {

    echo " Calling workspace_create function"
    stg=$(az storage account show --ids ${id})

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Create $1 workspace"
    echo  ""
    az storage container create \
            --name $1 \
            --auth-mode login \
            --account-name ${storage_account_name}

    mkdir -p ${TF_DATA_DIR}/tfstates/${TF_VAR_workspace}

    echo ""
}


function clean_up_variables {
        echo "cleanup variables"
        unset TF_VAR_lowerlevel_storage_account_name
        unset TF_VAR_lowerlevel_resource_group_name
        unset TF_VAR_lowerlevel_key
        unset LAUNCHPAD_NAME
        unset ARM_TENANT_ID
        unset ARM_SUBSCRIPTION_ID
        unset ARM_CLIENT_ID
        unset TF_VAR_rover_pilot_application_id
        unset ARM_CLIENT_SECRET
        unset TF_VAR_prefix
        unset TF_VAR_logged_user_objectId
        unset keyvault
}