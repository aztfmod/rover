for script in ${script_path}/tfcloud/*.sh; do
  source "$script"
done

error() {
    if [ "$LOG_TO_FILE" == "true" ];then
        local logFile=$CURRENT_LOG_FILE
        create_junit_report
        echo >&2 -e "\e[41mError: see log file $logFile\e[0m"
    fi

    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    local line_message=""
    local source="${3:-${BASH_SOURCE[1]}}"
    if [ "$parent_lineno" != "" ]; then
        line_message="on or near line ${parent_lineno}"
    fi

    if [[ -n "$message" ]]; then
        error_message="\e[41mError $source $line_message: ${message}; exiting with status ${code}\e[0m"
    else
        error_message="\e[41mError $source $line_message; exiting with status ${code}\e[0m"
    fi
    echo >&2 -e ${error_message}
    echo ""

    if [[ "${backend_type_hybrid}" == "remote" ]]; then
        tfcloud_runs_cancel ${error_message}
    fi
    clean_up_variables

    exit ${code}
}


#
# Execute a command and re-execute it with a backoff retry logic. This is mainly to handle throttling situations in CI
#
function execute_with_backoff {
    local max_attempts=${ATTEMPTS-5}
    local timeout=${TIMEOUT-20}
    local attempt=0
    local exitCode=0

    while [[ $attempt < $max_attempts ]]; do
        set +e
        "$@"
        exitCode=$?
        set -e

        if [[ $exitCode == 0 ]]; then
            break
        fi

        echo "Failure! Return code ${exitCode} - Retrying in $timeout.." 1>&2
        sleep $timeout
        attempt=$((attempt + 1))
        timeout=$((timeout * 2))
    done

    if [[ $exitCode != 0 ]]; then
        echo "Hit the max retry count ($@)" 1>&2
    fi

    return $exitCode
}

function parameter_value {
    if [[ ${2} = -* ]]; then
        error ${LINENO} "Value not set for paramater ${1}" 1
    fi

    echo ${2}
}

function process_actions {
    echo "@calling process_actions"

    case "${caf_command}" in
        bootstrap)
            bootstrap
            exit 0
            ;;
        ignite)
            ignite ${tf_command}
            exit 0
            ;;
        init)
            init
            exit 0
            ;;
        workspace)
            workspace ${tf_command}
            exit 0
            ;;
        walkthrough)
            execute_walkthrough
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
        tfc|remote)
            verify_parameters
            deploy ${TF_VAR_workspace}
            ;;
        ci)
            register_ci_tasks
            verify_ci_parameters
            set_default_parameters
            execute_ci_actions
            ;;
        cd)
            verify_cd_parameters
            set_default_parameters
            execute_cd
            ;;
        test)
            run_integration_tests "$base_directory"
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
    echo "  rover -lz [landingzone_folder_name] -a [plan|apply|destroy|validate|refresh|graph|import|output|taint|untaint|'state list'|'state rm'|'state show'|'show']"
    echo ""

}

function display_launchpad_instructions {
    echo ""
    warning "You need to deploy the launchpad from the rover by running (for production):"
    if [ -z "${TF_VAR_environment}" ]; then
        warning " rover -lz /tf/caf/landingzones/caf_launchpad -a apply -launchpad"
    else
        warning " rover -lz /tf/caf/landingzones/caf_launchpad -a apply -launchpad -env ${TF_VAR_environment}"
    fi
    echo ""
    echo "To create a simple remote state backend on Azure (for testing) [are optional]:"
    warning "Make sure you are connected with your Azure AD user before you run the rover init command."
    echo " rover init [-env myEnvironment] [-location southeastasia]"
    echo ""
    echo "To cleanup the azurerm backend storage account and keyvault:"
    echo " rover init --clean"
    echo
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

# The rover ignite command processes the jinja templates to generate json configuation file.
function ignite {
    echo "@calling verify_azure_session"

    command=(ansible-playbook ${caf_ignite_playbook} ${caf_ignite_environment})

    debug "running: ${command}"

    "${command[@]}"

}

# Isolate rover runs into isolated cached folder. Used to support parallel executions and keep trace of previous executions
# Note the launchpad cannot be executed in parallel to another execution as it has a built-in mecanism to recover in case of failure.
# Launchpad initialize in ~/.terraform.cache folder.
function setup_rover_job {
    job_id=$(date '+%Y%m%d%H%M%S%N')
    job_path="${1}/rover_jobs/${job_id}"
    modules_folder="${1}/modules"
    providers_folder="${1}/providers"
    mkdir -p "${job_path}"
    mkdir -p "${modules_folder}"
    mkdir -p "${providers_folder}"
    ln -s ${modules_folder} ${job_path}/modules
    ln -s ${providers_folder} ${job_path}/providers
    echo ${job_path}
}

function purge {
    echo "@calling purge"
    echo "purging ${TF_CACHE_FOLDER}"
    rm -rf ${TF_CACHE_FOLDER}
    rm -rf -- $HOME/*.tmp || true
    echo "Purged cache folder ${TF_CACHE_FOLDER}"
    exit 0
}

# The rover stores the Azure sessions in a local rover/.azure subfolder
# This function verifies the rover has an opened azure session
function verify_azure_session {
    echo "@calling verify_azure_session"

    if [ "${caf_command}" == "login" ]; then
        echo ""
        echo "Checking existing Azure session"
        session=$(az account show 2>/dev/null || true)

        if [ ! -z "${sp_keyvault_url}" ]; then
            login_as_sp_from_keyvault_secrets
        else

            if [ ! -z "$ARM_CLIENT_ID" ] && [ ! -z "$ARM_CLIENT_SECRET" ] && [ ! -z "$ARM_SUBSCRIPTION_ID" ] && [ ! -z "$ARM_TENANT_ID" ]; then
                warning "ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID are set in the parent shell but the Azure cli is connected to a user instead of a service principal"
                warning "Rover will therefore unset those environment variables to deploy with the current Azure cli context."
                warning "logout and login with the service principal:"
                warning 'az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET -t $ARM_TENANT_ID'
                warning
            fi

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
    else
        # If the session is a OIDC service principal we need to export the ARM variables
        if [ "${ARM_USE_OIDC}" == "true" ]; then
            export ARM_CLIENT_ID=$(echo $session | jq -r '.user.name')
            export ARM_TENANT_ID=$(echo $session | jq -r '.tenantId')
        fi
    fi
}

function login_as_sp_from_keyvault_secrets {
    information "Transition the current azure session to the credentials stored in the keyvault."
    information "It will merge this azure session into the existing ones."
    information "To prevent that, run az account clear before running this command."
    information ""

    keyvault_url=$(echo ${sp_keyvault_url} | sed 's/[^ ]\+ //') && echo "keyvault url: ${keyvault_url}"

    information "Getting secrets from keyvault ${keyvault_url} ..."

    # Test permissions
    az keyvault secret show --id ${sp_keyvault_url}/secrets/sp-client-id --query 'value' -o tsv  --only-show-errors | read CLIENT_ID

    if [ ! -z "${tenant}" ]; then
        export ARM_TENANT_ID=${tenant}
    else
        export ARM_TENANT_ID=$(az keyvault secret show --id ${sp_keyvault_url}/secrets/sp-tenant-id --query 'value' -o tsv --only-show-errors)
    fi

    information "Login to azure with tenant ${ARM_TENANT_ID}"

    export ARM_CLIENT_ID=$(az keyvault secret show --id ${sp_keyvault_url}/secrets/sp-client-id --query 'value' -o tsv --only-show-errors)
    export ARM_CLIENT_SECRET=$(az keyvault secret show --id ${sp_keyvault_url}/secrets/sp-client-secret --query 'value' -o tsv --only-show-errors)

    information "Login with service principal"
    az login --service-principal -u ${ARM_CLIENT_ID} -p ${ARM_CLIENT_SECRET} -t ${ARM_TENANT_ID}  --only-show-errors 1> /dev/null

    set +e
    trap - ERR
    trap - SIGHUP
    trap - SIGINT
    trap - SIGQUIT
    trap - SIGABRT

}

function check_subscription_required_role {
    echo "@checking if current user (object_id: ${TF_VAR_logged_user_objectId}) is ${1} of the subscription - only for launchpad"
    role=$(az role assignment list --role "${1}" --assignee ${TF_VAR_logged_user_objectId} --include-inherited --include-groups --only-show-errors)

    if [ "${role}" == "[]" ]; then
        error ${LINENO} "the current account must have ${1} privilege on the subscription to deploy launchpad." 2
    else
        echo "User is ${1} of the subscription"
    fi
}

function list_deployed_landingzones {
    echo "@calling list_deployed_landingzones"

    stg=$(az storage account show --ids ${id} -o json --only-show-errors)

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"

    echo ""
    echo "Landing zones deployed:"
    echo ""

    az storage blob list \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        -c ${TF_VAR_workspace} \
        --auth-mode login \
        --account-name ${storage_account_name} -o json |
        jq -r '["landing zone", "size in Kb", "last modification"], (.[] | [.name, .properties.contentLength / 1024, .properties.lastModified]) | @csv' |
        awk 'BEGIN{ FS=OFS="," }NR>1{ $2=sprintf("%.2f",$2) }1' |
        column -t -s ','

    echo ""
}

function get_tfstate_keyvault_name {
    keyvault=$(az graph query -q "Resources | where type == 'microsoft.keyvault/vaults' and ((tags.environment == '${TF_VAR_environment}' and tags.tfstate == '${TF_VAR_level}') or (tags.caf_environment == '${TF_VAR_environment}' and tags.caf_tfstate == '${TF_VAR_level}'))  | project name"  --query "data[0].name" -o tsv  --subscriptions ${TF_VAR_tfstate_subscription_id} --only-show-errors)
}

function login_as_launchpad {
    echo "@calling login_as_launchpad"

    echo ""
    echo "Getting launchpad coordinates from subscription: ${TF_VAR_tfstate_subscription_id}"

    get_tfstate_keyvault_name
    echo " - keyvault_name: ${keyvault}"

    stg=$(az storage account show --ids ${id} -o json --only-show-errors)

    export TF_VAR_tenant_id=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n tenant-id --vault-name ${keyvault} -o json --only-show-errors | jq -r .value ) && echo " - tenant_id : ${TF_VAR_tenant_id}"

    # If the logged in user does not have access to the launchpad
    if [ "${TF_VAR_tenant_id}" == "" ]; then
        error ${LINENO} "Not authorized to manage landingzones. User must be member of the security group to access the launchpad and deploy a landing zone" 102
    fi

    export TF_VAR_tfstate_storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name (current): ${TF_VAR_tfstate_storage_account_name}"
    export TF_VAR_lower_storage_account_name=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n lower-storage-account-name --vault-name ${keyvault} -o json 2>/dev/null | jq -r .value || true) && echo " - storage_account_name (lower): ${TF_VAR_lower_storage_account_name}"

    export TF_VAR_tfstate_resource_group_name=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group (current): ${TF_VAR_tfstate_resource_group_name}"
    export TF_VAR_lower_resource_group_name=$(az keyvault secret show --subscription ${TF_VAR_tfstate_subscription_id} -n lower-resource-group-name --vault-name ${keyvault} -o json 2>/dev/null | jq -r .value || true) && echo " - resource_group (lower): ${TF_VAR_lower_resource_group_name}"

    export TF_VAR_tfstate_container_name=${azurerm_workspace}
    export TF_VAR_lower_container_name=${azurerm_workspace}

    export TF_VAR_tfstate_key=${TF_VAR_tf_name}

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

    terraform_init

    RETURN_CODE=$? && echo "Terraform init return code ${RETURN_CODE}"

    case "${tf_action}" in
    "plan")
        echo "calling plan"
        plan
        ;;
    "apply")
        echo "calling apply"
        apply
        ;;
    "validate")
        echo "calling validate"
        validate
        ;;
    "show")
        echo "calling show"
        show
        ;;
    "destroy")
        echo "calling destroy"
        destroy
        ;;
    "graph")
        echo "calling graph"
        graph
        ;;
    "init")
        echo "init no-op"
        ;;
    *)
        other
        ;;
    esac

    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"

    cd "${current_path}"
}

##### workspace functions
## Workspaces are used for an additional level of isolation. Mainly used by CI
function workspace {

    echo "@calling workspace function with $@"
    get_storage_id

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
        -o json --only-show-errors)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Listing workspaces:"
    echo ""
    az storage container list \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --auth-mode "login" \
        --account-name ${storage_account_name} -o json  --only-show-errors |
        jq -r '["workspace", "last modification", "lease status"], (.[] | [.name, .properties.lastModified, .properties.leaseStatus]) | @csv' |
        column -t -s ','

    echo ""
}

function workspace_create {
    echo "@calling workspace_create"

    echo " Calling workspace_create function"
    stg=$(az storage account show \
        --ids ${id} -o json --only-show-errors)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Create $1 workspace"
    echo ""
    az storage container create \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name $1 \
        --auth-mode login \
        --account-name ${storage_account_name} --only-show-errors

    mkdir -p ${TF_VAR_environment}/${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}

    echo ""
}

function workspace_delete {
    echo "@calling workspace_delete"

    stg=$(az storage account show \
        --ids ${id} -o json --only-show-errors)

    export storage_account_name=$(echo ${stg} | jq -r .name)

    echo " Delete $1 workspace"
    echo ""
    az storage container delete \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name $1 \
        --auth-mode login \
        --account-name ${storage_account_name} --only-show-errors

    mkdir -p ${TF_VAR_environment}/${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}

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
    unset AZURE_ENVIRONMENT
    unset ARM_ENVIRONMENT
    unset TF_DATA_DIR

    echo "clean_up backend_files"
    tfstate_cleanup

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
        msiResource=${msi//MSIResource-/}
        ;;
    *"MSIClient"*)
        msiResource=$(az identity list --subscription ${TF_VAR_tfstate_subscription_id} --query "[?clientId=='${msi//MSIClient-/}'].{id:id}" -o tsv --only-show-errors)
        ;;
    *)
        echo "Warning: MSI identifier unknown."
        msiResource=${msi//MSIResource-/}
        ;;
    esac

    echo $msiResource
}

function export_azure_cloud_env {
    local tf_cloud_env=''

    # Set cloud variables for terraform
    unset AZURE_ENVIRONMENT
    unset ARM_ENVIRONMENT
    export AZURE_ENVIRONMENT=$(az cloud show --query name -o tsv --only-show-errors)

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

    # Set landingzone cloud variables for modules
    echo "Initalizing az cloud variables"
    while IFS="=" read key value; do
        log_debug " - TF_VAR_$key = $value"
        export "TF_VAR_$key=$value"
    done < <(az cloud show --only-show-errors | jq -r ".suffixes * .endpoints|to_entries|map(\"\(.key)=\(.value)\")|.[]")
}

function get_logged_user_object_id {
    echo "@calling_get_logged_user_object_id"

    export TF_VAR_user_type=$(az account show \
        --query user.type -o tsv --only-show-errors)

    export_azure_cloud_env

    if [ ${TF_VAR_user_type} == "user" ]; then

        unset ARM_TENANT_ID
        unset ARM_SUBSCRIPTION_ID
        unset ARM_CLIENT_ID
        unset ARM_CLIENT_SECRET
        unset TF_VAR_logged_aad_app_objectId

        export ARM_TENANT_ID=$(az account show -o json --only-show-errors | jq -r .tenantId)
        export TF_VAR_logged_user_objectId=$(az ad signed-in-user show --query id -o tsv --only-show-errors)
        export logged_user_upn=$(az ad signed-in-user show --query userPrincipalName -o tsv --only-show-errors)
        echo " - logged in user objectId: ${TF_VAR_logged_user_objectId} (${logged_user_upn})"

        echo "Initializing state with user: $(az ad signed-in-user show --query userPrincipalName -o tsv --only-show-errors)"
    else
        unset TF_VAR_logged_user_objectId
        export clientId=$(az account show --query user.name -o tsv --only-show-errors)

        get_tfstate_keyvault_name

        case "${clientId}" in
            "systemAssignedIdentity")
                if [ -z ${MSI_ID} ]; then
                    computerName=$(az rest --method get --headers Metadata=true --url http://169.254.169.254/metadata/instance?api-version=2020-09-01 | jq -r .compute.name)
                    az resource list -n ${computerName}
                    principalId=$(az resource list -n ${computerName} --query [*].identity.principalId --out tsv)
                    echo " - logged in Azure with System Assigned Identity - computer name - ${computerName}"
                    export TF_VAR_logged_user_objectId=${principalId}
                    export ARM_TENANT_ID=$(az account show --only-show-errors | jq -r .tenantId)
                else
                    echo " - logged in Azure with System Assigned Identity - ${MSI_ID}"
                    az identity show --ids ${MSI_ID}
                    export TF_VAR_logged_user_objectId=$(az identity show --ids ${MSI_ID} --query principalId -o tsv --only-show-errors 2>/dev/null)
                    export ARM_TENANT_ID=$(az identity show --ids ${MSI_ID} --query tenantId -o tsv --only-show-errors 2>/dev/null)
                fi
                ;;
            "userAssignedIdentity")
                msi=$(az account show --only-show-errors | jq -r .user.assignedIdentityInfo)
                echo " - logged in Azure with User Assigned Identity: ($msi)"
                msiResource=$(get_resource_from_assignedIdentityInfo "$msi")
                export TF_VAR_logged_aad_app_objectId=$(az identity show --ids $msiResource --query principalId -o tsv --only-show-errors 2>/dev/null)
                export TF_VAR_logged_user_objectId=$(az identity show --ids $msiResource --query principalId -o tsv --only-show-errors 2>/dev/null) && echo " Logged in rover msi object_id: ${TF_VAR_logged_user_objectId}"
                export ARM_CLIENT_ID=$(az identity show --ids $msiResource --query clientId -o tsv --only-show-errors 2>/dev/null)
                export ARM_TENANT_ID=$(az identity show --ids $msiResource --query tenantId -o tsv --only-show-errors 2>/dev/null)
                ;;
            *)
                # Service Principal
                # When connected with a service account the name contains the objectId
                export TF_VAR_logged_aad_app_objectId=$(az ad sp show --id ${clientId} --query id -o tsv --only-show-errors 2>/dev/null) && echo " Logged in rover app object_id: ${TF_VAR_logged_aad_app_objectId}"
                export TF_VAR_logged_user_objectId=${TF_VAR_logged_aad_app_objectId}
                warning " - logged in Azure AD application:  $(az ad sp show --id ${clientId} --query displayName -o tsv --only-show-errors 2>/dev/null)"
                ;;
        esac

    fi

    export TF_VAR_tenant_id=${ARM_TENANT_ID}
}

function deploy {
    echo "@deploy for gitops_terraform_backend_type set to '${gitops_terraform_backend_type}'"

    cd ${landingzone_name}
    if [ -f "$(git rev-parse --show-toplevel)/.gitmodules" ]; then
        version=$(cd $(git rev-parse --show-toplevel)/aztfmod &>/dev/null || cd $(git rev-parse --show-toplevel) && git branch -a --contains $(git rev-parse --short HEAD) || echo "from Terraform registry")
        information "CAF module version ($(git rev-parse --show-toplevel)/.gitmodules): $version"
    fi
    # for migration and hybrid support from azurerm to tfe
    azurerm_workspace=${TF_VAR_workspace}

    case "${tf_action}" in
        "migrate")
            migrate
            ;;
        *)
            if [ "${caf_command}" != "launchpad" ]; then
                tfstate_configure ${gitops_terraform_backend_type}
            fi

            if [ "${gitops_terraform_backend_type}" = "azurerm" ]; then
                deploy_azurerm
            else
                if ${backend_type_hybrid} ; then
                    get_storage_id
                    login_as_launchpad
                fi
                deploy_remote
            fi
            ;;
    esac
}

function checkout_module {
    if [ ! -z ${landingzone_name} ]; then
        # Update submodule branch based on .gitmodules
        cd ${landingzone_name}
        base_folder=$(git rev-parse --show-toplevel)

        if [ $? != 0 ]; then
        error ${LINEO} "landingzone folder not setup properly. Fix and restart."
        fi

        if [ ! $(git config --global --get safe.directory | grep "${base_folder}" 2>&1) ]; then
            git config --global --add safe.directory "${base_folder}"
        fi

        if [ -f "${base_folder}/.gitmodules" ]; then
            cd ${base_folder}
            if [ ! $(git config --global --get safe.directory | grep "${base_folder}/aztfmod" 2>&1) ]; then
                git config --global --add safe.directory "${base_folder}/aztfmod"
            fi
            # Improved logic required
            # Comment away for now: git submodule update --init procedure. This command enforce all rover deployments to use latest commit on caf repo. We need to be able to run rover with a spesific branch/tag of caf repo.
            # git submodule update --init --recursive --rebase --remote --checkout --force 2>&1
        fi
    fi
}

function deploy_azurerm {

    echo "@calling deploy_azurerm"
    get_storage_id
    get_logged_user_object_id

    case ${id} in
        "")
            warning "No launchpad found."
            if [ "${caf_command}" == "launchpad" ]; then
                if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
                    warning "Recover from an un-finished previous execution - ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
                    if [ "${tf_action}" == "destroy" ]; then
                        destroy
                    else
                        initialize_state
                    fi
                else
                    rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
                    if [ "${tf_action}" == "destroy" ]; then
                        warning "There is no launchpad in this subscription"
                    else
                        warning "Deploying from scratch the launchpad"
                        rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
                        initialize_state
                    fi
                    if [ "$devops" == "true" ]; then
                        echo "5"
                        return
                    else
                        echo "6"
                        exit
                    fi
                fi
            else
                error ${LINENO} "You need to initialise a launchpad first with the command \n
                rover /tf/caf/landingzones/caf_launchpad [plan | apply | destroy] -launchpad" 1000
            fi
            ;;
        *)

            # Get the launchpad version
            caf_launchpad=$(az storage account show --ids $id -o json | jq -r ".tags | .caf_launchpad,.launchpad | select( . != null )")
            echo ""
            warning "launchpad: ${caf_launchpad} already installed"
            echo ""

            if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
                warning "Recover from an un-finished previous execution"
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
                "plan"|"apply"|"validate"|"refresh"|"graph"|"import"|"output"|"taint"|"untaint"|"state list"|"state rm"|"state show"|"show")
                    deploy_from_azurerm_state
                    ;;
                "migrate")
                    migrate
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
    log_info "@calling landing_zone"

    get_storage_id

    case "${1}" in
    "list")
        log_info "Listing the deployed landing zones"
        list_deployed_landingzones
        ;;
    *)
        log_info "rover landingzone [ list ]"
        ;;
    esac
}

function expand_tfvars_folder {

    # Check the folder path exist
    if [ ! -d  ${1} ]; then
        error ${LINENO} "Folder ${1} does not exist." 1
    fi


    log_info " Expanding variable files: ${1}/*.tfvars"

    for filename in "${1}"/*.tfvars; do
        if [ "${filename}" != "${1}/*.tfvars" ]; then
            PARAMS+="-var-file ${filename} "
        fi
    done

    log_info " Expanding variable files: ${1}/*.tfvars.json"

    for filename in "${1}"/*.tfvars.json; do
        if [ "${filename}" != "${1}/*.tfvars.json" ]; then
            PARAMS+="-var-file ${filename} "
        fi
    done

    # Check there is some tfvars files
    if [ -z  "${PARAMS}" ]; then
        error ${LINENO} "Folder ${1} does not have any tfvars files." 1
    fi
}

function get_rover_version {

    if [ -f ${script_path}/version.txt ]; then
        echo $(cat ${script_path}/version.txt)
    else
        echo "local build"
    fi

}

#
# This function verifies the vscode container is running the version specified in the docker-compose
# of the .devcontainer sub-folder
#
function verify_rover_version {
    user=$(whoami)

    if [ "${ROVER_RUNNER}" = false ]; then
        required_version=$(cat /tf/caf/.devcontainer/docker-compose.yml | yq | jq -r '.services | first(.[]).image' || true)
        running_version=$(cat ${script_path}/version.txt |  egrep -o '[^\/]+$')

        if [ "${required_version}" != "${TF_VAR_rover_version}" ]; then
            information "The running version \"${TF_VAR_rover_version}\" does not match the required version ${required_version} of your local devcontainer (/tf/caf/.devcontainer/docker-compose.yml)."
            echo "Click on the Dev Container buttom on the left bottom corner and select rebuild container from the options."
            warning "or set the environment variable to skip the verification \"export ROVER_RUNNER=true\""
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

    account=$(az account show -o json --only-show-errors)

    target_subscription_name=$(echo ${account} | jq -r .name)
    target_subscription_id=$(echo ${account} | jq -r .id)

    export ARM_SUBSCRIPTION_ID=$(echo ${account} | jq -r .id)

    # Verify if the TF_VAR_tfstate_subscription_id variable has been set
    if [ -z ${TF_VAR_tfstate_subscription_id+x} ]; then
        echo "Set TF_VAR_tfstate_subscription_id variable to current session's subscription."
        export TF_VAR_tfstate_subscription_id=${ARM_SUBSCRIPTION_ID}
    fi

    export target_subscription_name=$(echo ${account} | jq -r .name)
    export target_subscription_id=$(echo ${account} | jq -r .id)

    echo "caf_command ${caf_command}"
    echo "target_subscription_id ${target_subscription_id}"
    echo "TF_VAR_tfstate_subscription_id ${TF_VAR_tfstate_subscription_id}"

    # Check if rover mode is set to launchpad
    if [[ ( ! -z "${sp_keyvault_url}") && ("${caf_command}" != "login") && ("${caf_command}" == "logout" ) ]]; then
        error 51 "To deploy the launchpad, the target and tfstate subscription must be the same."
    fi

    echo "Resources from this landing zone are going to be deployed in the following subscription:"
    echo ${account} | jq -r

    echo "debug: ${TF_VAR_tfstate_subscription_id}"
    tfstate_subscription_name=$(az account show -s ${TF_VAR_tfstate_subscription_id} --output json --only-show-errors | jq -r .name)
    echo "Tfstates subscription set to ${TF_VAR_tfstate_subscription_id} (${tfstate_subscription_name})"
    echo ""

}
