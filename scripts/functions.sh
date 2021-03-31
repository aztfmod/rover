
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

exit_if_error() {
  local exit_code=$1
  shift
  [[ $exit_code ]] &&               # do nothing if no error code passed
    ((exit_code != 0)) && {         # do nothing if error code is 0
      printf 'ERROR: %s\n' "$@" >&2 # we can use better logging here
      exit "$exit_code"             # we could also check to make sure
                                    # error code is numeric when passed
    }
}

#
# Execute a command and re-execute it with a backoff retry logic. This is mainly to handle throttling situations in CI
#
function execute_with_backoff {
  local max_attempts=${ATTEMPTS-5}
  local timeout=${TIMEOUT-20}
  local attempt=0
  local exitCode=0

  while [[ $attempt < $max_attempts ]]
  do
    set +e
    "$@"
    exitCode=$?
    set -e

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    echo "Failure! Return code ${exitCode} - Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "Hit the max retry count ($@)" 1>&2
  fi

  return $exitCode
}

function process_actions {
    echo "@calling process_actions"

    case "${caf_command}" in
        workspace)
            workspace ${tf_command}
            exit 0
            ;;
        clone)
            clone_repository
            exit 0
            ;;
        landingzone_mgmt)
            landing_zone ${tf_command}
            exit 0
            ;;
        launchpad|landingzone)
            verify_parameters
            deploy ${TF_VAR_workspace}
            ;;
        tfc)
            verify_parameters
            deploy_tfc ${TF_VAR_workspace}
            ;;
        *)
            display_instructions
    esac
}

function display_login_instructions {
    echo ""
    echo "To login the rover to azure:"
    echo " rover login --tenant [tenant_name.onmicrosoft.com or tenant_guid (optional)] --subscription [subscription_id_to_target(optional)]"
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
    echo "  rover -lz [landingzone_folder_name] -a [plan|apply|validate|import|taint|state list]"
    echo ""
    echo "List of the landingzones loaded in the rover:"

    if [ -d "/tf/caf/landingzones" ]; then
        for i in $(ls -d /tf/caf/landingzones/*); do echo ${i%%/}; done
        echo ""
    fi

    if [ -d "/tf/caf/public/landingzones" ]; then
        for i in $(ls -d /tf/caf/public/landingzones/*); do echo ${i%%/}; done
            echo ""
    fi
}

function display_launchpad_instructions {
    echo ""
    echo "You need to deploy the launchpad from the rover by running:"
    if [ -z "${TF_VAR_environment}" ]; then
        echo " rover -lz /tf/caf/public/landingzones/caf_launchpad -a apply -launchpad"
    else
        echo " rover -lz /tf/caf/public/landingzones/caf_launchpad -a apply -launchpad -env ${TF_VAR_environment}"
    fi
    echo ""
}

function verify_parameters {
    echo "@calling verify_parameters"

    if [ -z "${landingzone_name}" ]; then
        echo "landingzone                   : '' (not specified)"
        if [ ${caf_command} == "launchpad" ]; then
            display_instructions
            error ${LINENO} "action must be set when deploying a landing zone" 11
        fi
    else
        echo "landingzone                   : '$(echo ${landingzone_name})'"
        cd ${landingzone_name}
        export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
        export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}

        # Must provide an action when the tf_command is set
        if [ -z "${tf_action}" ]; then
            display_instructions
            error ${LINENO} "action must be set when deploying a landing zone" 11
        fi
    fi
}

# The rover stores the Azure sessions in a local rover/.azure subfolder
# This function verifies the rover has an opened azure session
function verify_azure_session {
    echo "@calling verify_azure_session"

    if [ "${caf_command}" == "login" ]; then
        echo ""
        echo "Checking existing Azure session"
        session=$(az account show 2>/dev/null || true)

        # Cleanup any service principal variables
        unset ARM_TENANT_ID
        unset ARM_SUBSCRIPTION_ID
        unset ARM_CLIENT_ID
        unset ARM_CLIENT_SECRET

        if [ ! -z "${tenant}" ]; then
            echo "Login to azure with tenant ${tenant}"
            ret=$(az login --use-device-code --tenant ${tenant} >/dev/null >&1)
        else
            ret=$(az login --use-device-code >/dev/null >&1)
        fi

        # the second parameter would be the subscription id to target
        if [ ! -z "${subscription}" ]; then
            echo "Set default subscription to ${subscription}"
            az account set -s ${subscription}
        fi

    fi

    if [ "${caf_command}" == "logout" ]; then
            echo "Closing Azure session"
            az logout || true

            # Cleaup any service principal session
            unset ARM_TENANT_ID
            unset ARM_SUBSCRIPTION_ID
            unset ARM_CLIENT_ID
            unset ARM_CLIENT_SECRET

            echo "Azure session closed"
            exit
    fi

    echo "Checking existing Azure session"
    session=$(az account show -o json 2>/dev/null || true)
    if [ "$session" == '' ]; then
            display_login_instructions
            error ${LINENO} "you must login to an Azure subscription first or 'rover login' again" 2
    fi

}

function check_subscription_required_role {
    echo "@checking if current user (object_id: ${TF_VAR_logged_user_objectId}) is ${1} of the subscription - only for launchpad"
    role=$(az role assignment list --role "${1}" --assignee ${TF_VAR_logged_user_objectId} --include-inherited --include-groups)

    if [ "${role}" == "[]" ]; then
           error ${LINENO} "the current account must have ${1} privilege on the subscription to deploy launchpad." 2
    else
        echo "User is ${1} of the subscription"
    fi
}

function list_deployed_landingzones {
    echo "@calling list_deployed_landingzones"

    stg=$(az storage account show --ids ${id} -o json)

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"

    echo ""
    echo "Landing zones deployed:"
    echo ""

    az storage blob list \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        -c ${TF_VAR_workspace} \
        --auth-mode login \
        --account-name ${storage_account_name} -o json |  \
    jq -r '["landing zone", "size in Kb", "last modification"], (.[] | [.name, .properties.contentLength / 1024, .properties.lastModified]) | @csv' | \
    awk 'BEGIN{ FS=OFS="," }NR>1{ $2=sprintf("%.2f",$2) }1'  | \
    column -t -s ','

    echo ""
}

function login_as_launchpad {
    echo "@calling login_as_launchpad"

    echo ""
    echo "Getting launchpad coordinates from subscription: ${TF_VAR_tfstate_subscription_id}"

    export keyvault=$(az keyvault list --subscription ${TF_VAR_tfstate_subscription_id} --query "[?tags.tfstate=='${TF_VAR_level}' && tags.environment=='${TF_VAR_environment}']" -o json | jq -r .[0].name)

    echo " - keyvault_name: ${keyvault}"

    stg=$(az storage account show --ids ${id} -o json)

    export TF_VAR_tenant_id=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n tenant-id --vault-name ${keyvault} -o json | jq -r .value) && echo " - tenant_id : ${TF_VAR_tenant_id}"

    # If the logged in user does not have access to the launchpad
    if [ "${TF_VAR_tenant_id}" == "" ]; then
        error 326 "Not authorized to manage landingzones. User must be member of the security group to access the launchpad and deploy a landing zone" 102
    fi

    export TF_VAR_tfstate_storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name (current): ${TF_VAR_tfstate_storage_account_name}"
    export TF_VAR_lower_storage_account_name=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n lower-storage-account-name --vault-name ${keyvault} -o json 2>/dev/null | jq -r .value || true) && echo " - storage_account_name (lower): ${TF_VAR_lower_storage_account_name}"

    export TF_VAR_tfstate_resource_group_name=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group (current): ${TF_VAR_tfstate_resource_group_name}"
    export TF_VAR_lower_resource_group_name=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n lower-resource-group-name --vault-name ${keyvault} -o json 2>/dev/null | jq -r .value || true) && echo " - resource_group (lower): ${TF_VAR_lower_resource_group_name}"

    export TF_VAR_tfstate_container_name=${TF_VAR_workspace}
    export TF_VAR_lower_container_name=${TF_VAR_workspace}

    export TF_VAR_tfstate_key=${TF_VAR_tf_name}


    if [ ${caf_command} == "landingzone" ]; then

        if [ ${impersonate} = true ]; then
            export SECRET_PREFIX=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n launchpad-secret-prefix --vault-name ${keyvault} -o json | jq -r .value) && echo " - Name: ${SECRET_PREFIX}"
            echo "Set terraform provider context to Azure AD application launchpad "
            export ARM_CLIENT_ID=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n ${SECRET_PREFIX}-client-id --vault-name ${keyvault} -o json | jq -r .value) && echo " - client id: ${ARM_CLIENT_ID}"
            export ARM_CLIENT_SECRET=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n ${SECRET_PREFIX}-client-secret --vault-name ${keyvault} -o json | jq -r .value)
            export ARM_TENANT_ID=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n ${SECRET_PREFIX}-tenant-id --vault-name ${keyvault} -o json | jq -r .value) && echo " - tenant id: ${ARM_TENANT_ID}"
            export TF_VAR_logged_aad_app_objectId=$(az ad sp show --subscription ${TF_VAR_tfstate_subscription_id} --id ${ARM_CLIENT_ID} --query objectId -o tsv) && echo " - Set logged in aad app object id from keyvault: ${TF_VAR_logged_aad_app_objectId}"

            echo "Impersonating with the azure session with the launchpad service principal to deploy the landingzone"
            az login --service-principal -u ${ARM_CLIENT_ID} -p ${ARM_CLIENT_SECRET} --tenant ${ARM_TENANT_ID}
        fi

    fi

}

function deploy_landingzone {
    echo "@calling deploy_landingzone"

    echo "Deploying '${landingzone_name}'"

    cd ${landingzone_name}

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"
    rm -f -- "${TF_DATA_DIR}/terraform.tfstate"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    terraform init  -reconfigure=true \
        -backend=true \
        -get-plugins=true \
        -upgrade=true \
        -backend-config storage_account_name=${TF_VAR_tfstate_storage_account_name} \
        -backend-config resource_group_name=${TF_VAR_tfstate_resource_group_name} \
        -backend-config container_name=${TF_VAR_workspace} \
        -backend-config key=${TF_VAR_tf_name} \
        -backend-config subscription_id=${TF_VAR_tfstate_subscription_id} \
        ${landingzone_name}

    RETURN_CODE=$? && echo "Terraform init return code ${RETURN_CODE}"

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

    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"
    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"

    cd "${current_path}"
}

##### workspace functions
## Workspaces are used for an additional level of isolation. Mainly used by CI
function workspace {

    echo "@calling workspace function with $@"
    get_storage_id

    if [ "${id}" == "null" ]; then
            display_launchpad_instructions
            exit 1000
    fi

    case "${1}" in
        "list")
            workspace_list
            ;;
        "create")
            workspace_create ${2}
            ;;
        "delete")
            workspace_delete ${2}
            ;;
        *)
            echo "launchpad workspace [ list | create | delete ]"
            ;;
    esac
}

function workspace_list {
    echo "@calling workspace_list"

    echo " Calling workspace_list function"
    stg=$(az storage account show \
        --ids ${id} \
        -o json)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Listing workspaces:"
    echo  ""
    az storage container list \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --auth-mode "login" \
        --account-name ${storage_account_name} -o json |  \
    jq -r '["workspace", "last modification", "lease ststus"], (.[] | [.name, .properties.lastModified, .properties.leaseStatus]) | @csv' | \
    column -t -s ','

    echo ""
}

function workspace_create {
    echo "@calling workspace_create"

    echo " Calling workspace_create function"
    stg=$(az storage account show \
        --ids ${id} -o json)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Create $1 workspace"
    echo  ""
    az storage container create \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name $1 \
        --auth-mode login \
        --account-name ${storage_account_name}

    mkdir -p ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}

    echo ""
}

function workspace_delete {
    echo "@calling workspace_delete"

    stg=$(az storage account show \
        --ids ${id} -o json)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Delete $1 workspace"
    echo  ""
    az storage container delete \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name $1 \
        --auth-mode login \
        --account-name ${storage_account_name}

    mkdir -p ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}

    echo ""
}

function clean_up_variables {
    echo "@calling clean_up_variables"

    echo "cleanup variables"
    unset TF_VAR_lower_storage_account_name
    unset TF_VAR_lower_resource_group_name
    unset TF_VAR_lower_key
    unset LAUNCHPAD_NAME
    unset ARM_TENANT_ID
    unset ARM_SUBSCRIPTION_ID
    unset ARM_CLIENT_ID
    unset ARM_USE_MSI
    unset ARM_SAS_TOKEN
    unset ARM_CLIENT_SECRET
    unset TF_VAR_logged_user_objectId
    unset TF_VAR_logged_aad_app_objectId
    unset keyvault

    echo "clean_up backend_files"
    find /tf/caf -name  backend.azurerm.tf -delete

}

function get_resource_from_assignedIdentityInfo {
    msi=$1
    msiResource=""

    if [ -z "$msi" ]; then
        echo "Missing Assigned Identity Info!"
        return 1
    fi

    case $msi in
        *"MSIResource"*)
            msiResource= ${msi//MSIResource-}
        ;;
        *"MSIClient"*)
            msiResource=$(az identity list --query "[?clientId=='${msi//MSIClient-}'].{id:id}" -o tsv)
        ;;
        *)
            echo "Warning: MSI identifier unknown."
            msiResource= ${msi//MSIResource-}
        ;;
    esac

    echo $msiResource
}

function set_arm_tenant_id_user_assigned_client {
    # If User Assigned MSI is used to provision the launchpad
    if [ "$TF_VAR_level" == "level0" ]; then
        export ARM_TENANT_ID=$(az account show | jq -r '.tenantId')
    else
        export ARM_TENANT_ID=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n tenant-id --vault-name ${keyvault} -o json | jq -r .value) && echo " - tenant_id : ${ARM_TENANT_ID}"
    fi
}

function export_azure_cloud_env {
    local tf_cloud_env=''

    unset AZURE_ENVIRONMENT
    unset ARM_ENVIRONMENT
    export AZURE_ENVIRONMENT=$(az cloud show --query name -o tsv)

    if [ -z "$cloud_name" ]; then

        case $AZURE_ENVIRONMENT in
            AzureCloud)
            tf_cloud_env='public'
            ;;
            AzureChinaCloud)
            tf_cloud_env='china'
            ;;
            AzureUSGovernment)
            tf_cloud_env='usgovernment'
            ;;
            AzureGermanCloud)
            tf_cloud_env='german'
            ;;
        esac

        export ARM_ENVIRONMENT=$tf_cloud_env
    else
        export ARM_ENVIRONMENT=$cloud_name
    fi

    echo " - AZURE_ENVIRONMENT: ${AZURE_ENVIRONMENT}"
    echo " - ARM_ENVIRONMENT: ${ARM_ENVIRONMENT}"
}

function get_logged_user_object_id {
    echo "@calling_get_logged_user_object_id"

    export TF_VAR_user_type=$(az account show \
        --query user.type -o tsv)

    export_azure_cloud_env

    if [ ${TF_VAR_user_type} == "user" ]; then

        unset ARM_TENANT_ID
        unset ARM_SUBSCRIPTION_ID
        unset ARM_CLIENT_ID
        unset ARM_CLIENT_SECRET
        unset TF_VAR_logged_aad_app_objectId

        export TF_VAR_tenant_id=$(az account show -o json | jq -r .tenantId)
        export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query objectId -o tsv)
        export logged_user_upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
        echo " - logged in user objectId: ${TF_VAR_logged_user_objectId} (${logged_user_upn})"

        echo "Initializing state with user: $(az ad signed-in-user show --query userPrincipalName -o tsv)"
    else
        unset TF_VAR_logged_user_objectId
        export clientId=$(az account show --query user.name -o tsv)

        export keyvault=$(az keyvault list --subscription ${TF_VAR_tfstate_subscription_id} --query "[?tags.tfstate=='${TF_VAR_level}' && tags.environment=='${TF_VAR_environment}']" -o json | jq -r .[0].name)

        case "${clientId}" in
            "systemAssignedIdentity")
                echo " - logged in Azure with System Assigned Identity - ${MSI_ID}"
                export TF_VAR_logged_user_objectId=$(az identity show --ids ${MSI_ID} --query principalId -o tsv)
                export ARM_TENANT_ID=$(az identity show --ids ${MSI_ID} --query tenantId -o tsv)
                ;;
            "userAssignedIdentity")
                echo " - logged in Azure with User Assigned Identity: ($(az account show -o json | jq -r .user.assignedIdentityInfo))"
                msi=$(az account show | jq -r .user.assignedIdentityInfo)
                msiResource=$(get_resource_from_assignedIdentityInfo "$msi")
                export TF_VAR_logged_aad_app_objectId=$(az identity show --ids $msiResource | jq -r .principalId)
                export TF_VAR_logged_user_objectId=$(az identity show --ids $msiResource | jq -r .principalId) && echo " Logged in rover msi object_id: ${TF_VAR_logged_user_objectId}"
                export ARM_CLIENT_ID=$(az identity show --ids $msiResource | jq -r .clientId)
                set_arm_tenant_id_user_assigned_client
                ;;
            *)
                # When connected with a service account the name contains the objectId
                export TF_VAR_logged_aad_app_objectId=$(az ad sp show --id ${clientId} --query objectId -o tsv) && echo " Logged in rover app object_id: ${TF_VAR_logged_aad_app_objectId}"
                export TF_VAR_logged_user_objectId=$(az ad sp show --id ${clientId} --query objectId -o tsv) && echo " Logged in rover app object_id: ${TF_VAR_logged_aad_app_objectId}"
                echo " - logged in Azure AD application:  $(az ad sp show --id ${clientId} --query displayName -o tsv)"
                ;;
        esac

        export TF_VAR_tenant_id=${ARM_TENANT_ID}

    fi
}

function deploy {

    echo "@calling_deploy"

    get_storage_id
    get_logged_user_object_id

    case ${id} in
        "")
            echo "No launchpad found."
            if [ "${caf_command}" == "launchpad" ]; then
                if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
                    echo "Recover from an un-finished previous execution"
                    if [ "${tf_action}" == "destroy" ]; then
                        destroy
                    else
                        initialize_state
                    fi
                else
                    rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
                    if [ "${tf_action}" == "destroy" ]; then
                        echo "There is no launchpad in this subscription"
                    else
                        echo "Deploying from scratch the launchpad"
                        rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
                        initialize_state
                    fi
                    exit
                fi
            else
                error ${LINENO} "You need to initialise a launchpad first with the command \n
                rover /tf/caf/landingzones/launchpad [plan | apply | destroy] -launchpad" 1000
            fi
        ;;
        *)

        # Get the launchpad version
        caf_launchpad=$(az storage account show --ids $id -o json | jq -r .tags.launchpad)
        echo ""
        echo "${caf_launchpad} already installed"
        echo ""

        if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
            echo "Recover from an un-finished previous execution"
            if [ "${tf_action}" == "destroy" ]; then
                if [ "${caf_command}" == "landingzone" ]; then
                    login_as_launchpad
                fi
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
            "plan"|"apply"|"validate"|"import"|"output"|"taint"|"state list"|"state rm"|"state show")
                deploy_from_remote_state
                ;;
            *)
                display_instructions
                ;;
            esac
        fi
        ;;
    esac


}

function landing_zone {
    echo "@calling landing_zone"

    get_storage_id

    case "${1}" in
        "list")
            echo "Listing the deployed landing zones"
            list_deployed_landingzones
                ;;
        *)
            echo "rover landingzone [ list ]"
            ;;
    esac
}

function expand_tfvars_folder {

  echo " Expanding variable files: ${1}/*.tfvars"

  for filename in "${1}"/*.tfvars; do
    if [ "${filename}" != "${1}/*.tfvars" ]; then
        PARAMS+="-var-file ${filename} "
    fi
  done

  echo " Expanding variable files: ${1}/*.tfvars.json"

   for filename in "${1}"/*.tfvars.json; do
    if [ "${filename}" != "${1}/*.tfvars.json" ]; then
        PARAMS+="-var-file ${filename} "
    fi
  done
}

#
# This function verifies the vscode container is running the version specified in the docker-compose
# of the .devcontainer sub-folder
#
function verify_rover_version {
    user=$(whoami)

    if [ "${ROVER_RUNNER}" = false ]; then
        required_version=$(cat /tf/caf/.devcontainer/docker-compose.yml | yq | jq -r '.services | first(.[]).image' | awk -F'/' '{print $2}')
        running_version=$(cat /tf/rover/version.txt | awk -F'/' '{print $2}')

        if [ "${required_version}" != "${running_version}" ]; then
            echo "The version of your local devcontainer ${running_version} does not match the required version ${required_version}."
            echo "Click on the Dev Container buttom on the left bottom corner and select rebuild container from the options."
            exit
        fi
    fi
}

function process_target_subscription {
    echo "@calling process_target_subscription"

    if [ ! -z "${target_subscription}" ]; then
        echo "Set subscription to -target_subscription ${target_subscription}"
        az account set -s "${target_subscription}"
    fi

    account=$(az account show -o json)

    target_subscription_name=$( echo ${account} | jq -r .name)
    target_subscription_id=$( echo ${account} | jq -r .id)

    export ARM_SUBSCRIPTION_ID=$(echo ${account} | jq -r .id)

    # Verify if the TF_VAR_tfstate_subscription_id variable has been set
    if [ -z ${TF_VAR_tfstate_subscription_id+x} ]; then
        echo "Set TF_VAR_tfstate_subscription_id variable to current session's subscription."
        export TF_VAR_tfstate_subscription_id=${ARM_SUBSCRIPTION_ID}
    fi

    export target_subscription_name=$( echo ${account} | jq -r .name)
    export target_subscription_id=$( echo ${account} | jq -r .id)

    echo "caf_command ${caf_command}"
    echo "target_subscription_id ${target_subscription_id}"
    echo "TF_VAR_tfstate_subscription_id ${TF_VAR_tfstate_subscription_id}"

    # Check if rover mode is set to launchpad
    if [[ ( "${caf_command}" == "launchpad" ) && ( "${target_subscription_id}" != "${TF_VAR_tfstate_subscription_id}" ) ]]; then
        error 51 "To deploy the launchpad, the target and tfstate subscription must be the same."
    fi

    echo "Resources from this landing zone are going to be deployed in the following subscription:"
    echo ${account} | jq -r


    echo "debug: ${TF_VAR_tfstate_subscription_id}"
    tfstate_subscription_name=$(az account show -s ${TF_VAR_tfstate_subscription_id} --output json | jq -r .name)
    echo "Tfstates subscription set to ${TF_VAR_tfstate_subscription_id} (${tfstate_subscription_name})"
    echo ""

}
