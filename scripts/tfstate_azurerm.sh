function initialize_state {
    echo "@calling initialize_state"

    echo "Checking required permissions"
    if [ ${skip_permission_check} == true ]; then
        echo "Checking required permissions - Skipped as --skip-permission-check was found."
    else
        check_subscription_required_role "Owner"
    fi

    echo "Installing launchpad from ${landingzone_name}"
    cd ${landingzone_name}

    sudo rm -f -- ${landingzone_name}/backend.azurerm.tf

    rm -f -- "${TF_DATA_DIR}/terraform.tfstate"

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version 0.15 or greater"
            terraform -chdir=${landingzone_name} \
                init \
                -upgrade=true
            ;;
        *)
            terraform init \
                -get-plugins=true \
                -upgrade=true \
                ${landingzone_name}
            ;;
    esac

    RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

    case "${tf_action}" in
    "plan")
        echo "calling plan"
        plan
        ;;
    "apply")
        echo "calling plan and apply"
        plan
        apply
        get_storage_id
        upload_tfstate
        ;;
    "validate")
        echo "calling validate"
        validate
        ;;
    "destroy")
        echo "No more tfstate file"
        exit
        ;;
    *)
        other
        ;;
    esac

    rm -rf backend.azurerm.tf || true

    cd "${current_path}"
    
    if [ "$devops" != "true" ]; then
        exit 0
    fi
}

function upload_tfstate {
    echo "@calling upload_tfstate"

    echo "Moving launchpad to the cloud"

    stg=$(az storage account show --ids ${id} -o json)

    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
    export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
    export access_key=$(az storage account keys list --subscription ${TF_VAR_tfstate_subscription_id} --account-name ${storage_account_name} --resource-group ${resource_group} -o json | jq -r .[0].value) && echo " - storage_key: retrieved"

    az storage blob upload -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        --container-name ${TF_VAR_workspace} \
        --name ${TF_VAR_tf_name} \
        --account-name ${storage_account_name} \
        --auth-mode key \
        --account-key ${access_key} \
        --no-progress

    RETURN_CODE=$?
    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error uploading the blob storage" $RETURN_CODE
    fi

    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" || true

}

function download_tfstate {
    echo "@calling download_tfstate"

    echo "Downloading Remote state from the cloud"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    
    stg=$(az storage account show --ids ${id} -o json)
    stg_name=$(az storage account show --ids ${id} -o json | jq -r .name)
    export storage_account_name=$(echo ${stg} | jq -r .name) && echo " - storage_account_name: ${storage_account_name}"
    export resource_group=$(echo ${stg} | jq -r .resourceGroup) && echo " - resource_group: ${resource_group}"
    export access_key=$(az storage account keys list --subscription ${TF_VAR_tfstate_subscription_id} --account-name ${storage_account_name} --resource-group ${resource_group} -o json | jq -r .[0].value) && echo " - storage_key: retrieved"

    az storage blob download \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name ${TF_VAR_tf_name} \
        --file "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        --container-name ${TF_VAR_workspace} \
        --auth-mode "key" \
        --account-name ${stg_name} \
        --account-key ${access_key} \
        --no-progress

    RETURN_CODE=$?
    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error Downloading the blob storage" $RETURN_CODE
    fi
}

function deploy_from_remote_state {
    echo "@calling deploy_from_remote_state"

    echo 'Connecting to the launchpad'
    cd ${landingzone_name}

    if [ -f "backend.azurerm" ]; then
        sudo cp backend.azurerm backend.azurerm.tf
    fi

    login_as_launchpad

    deploy_landingzone

    rm -rf backend.azurerm.tf

    cd "${current_path}"
}

function destroy_from_remote_state {
    echo "@calling destroy_from_remote_state"

    echo "Destroying from remote state"
    echo 'Connecting to the launchpad'
    cd ${landingzone_name}

    login_as_launchpad

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"

    # Cleanup previous deployments
    rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    rm -rf "${TF_DATA_DIR}/tfstates/terraform.tfstate"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    stg_name=$(az storage account show --ids ${id} -o json | jq -r .name)

    fileExists=$(az storage blob exists \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --name ${TF_VAR_tf_name} \
        --container-name ${TF_VAR_workspace} \
        --auth-mode 'login' \
        --account-name ${stg_name} -o json | jq .exists)

    if [ "${fileExists}" == "true" ]; then
        if [ ${caf_command} == "launchpad" ]; then
            az storage blob download \
                --subscription ${TF_VAR_tfstate_subscription_id} \
                --name ${TF_VAR_tf_name} \
                --file "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                --container-name ${TF_VAR_workspace} \
                --auth-mode "login" \
                --account-name ${stg_name} \
                --no-progress

            RETURN_CODE=$?
            if [ $RETURN_CODE != 0 ]; then
                error ${LINENO} "Error downloading the blob storage" $RETURN_CODE
            fi

            destroy
        else
            destroy "remote"
        fi
    else
        echo "landing zone already deleted"
    fi

    cd "${current_path}"
}

function terraform_init_remote {

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version 0.15 or greater"
            terraform -chdir=${landingzone_name} \
                init \
                -reconfigure \
                -backend=true \
                -upgrade=true \
                -backend-config storage_account_name=${TF_VAR_tfstate_storage_account_name} \
                -backend-config resource_group_name=${TF_VAR_tfstate_resource_group_name} \
                -backend-config container_name=${TF_VAR_workspace} \
                -backend-config key=${TF_VAR_tf_name} \
                -backend-config subscription_id=${TF_VAR_tfstate_subscription_id}
            ;;
        *)
            terraform init \
                -reconfigure=true \
                -backend=true \
                -get-plugins=true \
                -upgrade=true \
                -backend-config storage_account_name=${TF_VAR_tfstate_storage_account_name} \
                -backend-config resource_group_name=${TF_VAR_tfstate_resource_group_name} \
                -backend-config container_name=${TF_VAR_workspace} \
                -backend-config key=${TF_VAR_tf_name} \
                -backend-config subscription_id=${TF_VAR_tfstate_subscription_id} \
                ${landingzone_name}
            ;;
    esac
}


function purge_command {
  PARAMS=''
  case "${1}" in
    graph)
      shift 1
      purge_command_graph $@
      ;;
    plan)
      shift 1
      purge_command_plan $@
      ;;
  esac

  echo $PARAMS
}

function purge_command_graph {
  while (( "$#" )); do
    case "${1}" in
      -var-file)
        shift 2
        ;;
      *)
        PARAMS+="${1} "
        shift 1
        ;;
    esac      
  done
}


function purge_command_plan {
  while (( "$#" )); do
    case "${1}" in
      -draw-cycles)
        shift 1
        ;;
      "-type"*)
        shift 1
        ;;
      *)
        PARAMS+="${1} "
        shift 1
        ;;
    esac      
  done
}


function plan {
    echo "@calling plan"

    plan_command=$(purge_command plan ${tf_command})
    echo "running terraform plan with ${plan_command}"
    echo " -TF_VAR_workspace: ${TF_VAR_workspace}"
    echo " -state: ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    echo " -plan:  ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"

    pwd
    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    rm -f $STDERR_FILE

    local colorFlag=""
    if [ "$tf_no_color" == "true" ]; then
      colorFlag="-no-color"
    fi
    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version 0.15 or greater"
            terraform -chdir=${landingzone_name} \
                plan ${plan_command} \
                -refresh=true \
                -detailed-exitcode \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                -out="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"  | tee ${tf_output_file}
            ;;
        *)
            terraform plan ${plan_command} \
                -refresh=true \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                -out="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" $PWD | tee ${tf_output_file}
            ;;
    esac
    
    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform plan return code: ${RETURN_CODE}"

    if [ ! -z ${tf_output_plan_file} ]; then
        echo "Copying plan file to ${tf_output_plan_file}"
        cp "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" "${tf_output_plan_file}"
    fi

    case "${RETURN_CODE}" in
      "0")
        export text_log_status="terraform plan succeeded"
        ;;
      "1")        
        error ${LINENO} "Error running terraform plan" $RETURN_CODE
        ;;
      "2")
        log_info "terraform plan succeeded with non-empty diff"
        export text_log_status="terraform plan succeeded with non-empty diff"
        ;;
    esac    

    # Temporary fix until plan and apply properly decoupled.
    # if [ $RETURN_CODE != 0 ]; then
    #     error ${LINENO} "Error running terraform plan" $RETURN_CODE
    # fi
}

function apply {
    echo "@calling apply"

    echo 'running terraform apply'
    rm -f $STDERR_FILE

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version 0.15 or greater"
            terraform -chdir=${landingzone_name} \
                apply \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" | tee ${tf_output_file}
            ;;
        *)
            terraform apply \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" | tee ${tf_output_file}
            ;;
    esac

    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform apply return code: ${RETURN_CODE}"

    if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "Error running terraform apply" $RETURN_CODE
    else
      export text_log_status="terraform apply succeeded"
    fi

}

function validate {
    echo "@calling validate"

    echo 'running terraform validate'
    terraform validate

    RETURN_CODE=$? && echo "Terraform validate return code: ${RETURN_CODE}"

    if [ -s $STDERR_FILE ]; then
        if [ ${tf_output_file+x} ]; then cat $STDERR_FILE >>${tf_output_file}; fi
        echo "Terraform returned errors:"
        cat $STDERR_FILE
        RETURN_CODE=2002
    fi

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform validate" $RETURN_CODE
    fi

}

function graph {
    echo "@calling graph"

    graph_command=$(purge_command graph ${tf_command})
    echo "running terraform ${tf_action} -plan="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" ${graph_command}"

    echo "calling plan"
    plan

    echo "calling terraform graph"
    terraform graph \
        -plan="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" ${graph_command}

    set +e
}

function destroy {
    echo "@calling destroy $1"

    cd ${landingzone_name}

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}

    echo "Calling function destroy"
    echo " -TF_VAR_workspace: ${TF_VAR_workspace}"
    echo " -TF_VAR_tf_name: ${TF_VAR_tf_name}"

    rm -f "${TF_DATA_DIR}/terraform.tfstate"
    sudo rm -f ${landingzone_name}/backend.azurerm.tf

    if [ "$1" == "remote" ]; then

        if [ -e backend.azurerm ]; then
            sudo cp -f backend.azurerm backend.azurerm.tf
        fi

        # if [ -z "${ARM_USE_MSI}" ]; then
        #     export ARM_ACCESS_KEY=$(az storage account keys list --subscription ${TF_VAR_tfstate_subscription_id} --account-name ${TF_VAR_tfstate_storage_account_name} --resource-group ${TF_VAR_tfstate_resource_group_name} -o json | jq -r .[0].value)
        # fi

        echo 'running terraform destroy remote'
        terraform_init_remote

        RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

        case ${terraform_version} in
            *"15"* | *"1."*)
                echo "Terraform version 0.15 or greater"
                terraform -chdir=${landingzone_name} \
                    destroy \
                    -refresh=false \
                    ${tf_command} ${tf_approve}
                ;;
            *)
                terraform destroy \
                    -refresh=false \
                    ${tf_command} ${tf_approve} \
                    ${landingzone_name}
                ;;
        esac

        RETURN_CODE=$?
        if [ $RETURN_CODE != 0 ]; then
            error ${LINENO} "Error running terraform destroy" $RETURN_CODE
        fi

        get_storage_id

    else
        echo 'running terraform destroy with local tfstate'
        # Destroy is performed with the logged in user who last ran the launchap .. apply from the rover. Only this user has permission in the kv access policy
        if [ ${TF_VAR_user_type} == "user" ]; then
            unset ARM_TENANT_ID
            unset ARM_SUBSCRIPTION_ID
            unset ARM_CLIENT_ID
            unset ARM_CLIENT_SECRET
        fi

        case ${terraform_version} in
            *"15"* | *"1."*)
                echo "Terraform version 0.15 or greater"
                terraform -chdir=${landingzone_name} \
                    init \
                    -reconfigure=true \
                    -upgrade=true
                ;;
            *)
                terraform init \
                    -reconfigure=true \
                    -get-plugins=true \
                    -upgrade=true \
                    ${landingzone_name}
                ;;
        esac

        RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

        echo "using tfstate from ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
        mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

        case ${terraform_version} in
            *"15"* | *"1."*)
                echo "Terraform version 0.15 or greater"
                terraform -chdir=${landingzone_name} \
                    destroy ${tf_command} ${tf_approve} \
                    -refresh=false \
                    -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
                ;;
            *)
                terraform destroy ${tf_command} ${tf_approve} \
                    -refresh=false \
                    -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                    ${landingzone_name}
                ;;
        esac

        RETURN_CODE=$?
        if [ $RETURN_CODE != 0 ]; then
            error ${LINENO} "Error running terraform destroy" $RETURN_CODE
        fi
    fi

    echo "Removing ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    rm -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    get_storage_id

    if [[ ! -z ${id} ]]; then
        echo "Delete state file on storage account:"
        echo " -tfstate: ${TF_VAR_tf_name}"
        stg_name=$(az storage account show \
            --ids ${id} -o json |
            jq -r .name) && echo " -stg_name: ${stg_name}"

        fileExists=$(az storage blob exists \
            --subscription ${TF_VAR_tfstate_subscription_id} \
            --name ${TF_VAR_tf_name} \
            --container-name ${TF_VAR_workspace} \
            --auth-mode login \
            --account-name ${stg_name} -o json |
            jq .exists)

        if [ "${fileExists}" == "true" ]; then
            echo " -found"
            az storage blob delete \
                --subscription ${TF_VAR_tfstate_subscription_id} \
                --name ${TF_VAR_tf_name} \
                --container-name ${TF_VAR_workspace} \
                --delete-snapshots include \
                --auth-mode login \
                --account-name ${stg_name}
            echo " -deleted"
        fi
    fi

    rm -rf ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}

    clean_up_variables
}

function other {
    echo "@calling other"

    echo "running terraform ${tf_action} -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"  ${tf_command}"

    rm -f $STDERR_FILE

    terraform ${tf_action} \
        -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        ${tf_command} 2>$STDERR_FILE | tee ${tf_output_file}

    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform ${tf_action} return code: ${RETURN_CODE}"

    if [ -s $STDERR_FILE ]; then
        if [ ${tf_output_file+x} ]; then cat $STDERR_FILE >>${tf_output_file}; fi
        echo "Terraform returned errors:"
        cat $STDERR_FILE
        RETURN_CODE=2003
    fi

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform ${tf_action}" $RETURN_CODE
    fi
}

function get_storage_id {
    echo "@calling get_storage_id"
    id=$(execute_with_backoff az storage account list \
        --subscription ${TF_VAR_tfstate_subscription_id} \
        --query "[?tags.tfstate=='${TF_VAR_level}' && tags.environment=='${TF_VAR_environment}'].{id:id}[0]" -o json | jq -r .id)

    if [[ ${id} == null ]] && [ "${caf_command}" != "launchpad" ]; then
        # Check if other launchpad are installed
        id=$(execute_with_backoff az storage account list \
            --subscription ${TF_VAR_tfstate_subscription_id} \
            --query "[?tags.tfstate=='${TF_VAR_level}'].{id:id}[0]" -o json | jq -r .id)

        if [ ${id} == null ]; then
            if [ ${TF_VAR_level} != "level0" ]; then
                echo "You need to initialize that level first before using it or you do not have permission to that level."
            else
                display_launchpad_instructions
            fi
            exit 1000
        else
            echo
            echo "There is no remote state for ${TF_VAR_level} in the environment ${TF_VAR_environment} in the subscription ${TF_VAR_tfstate_subscription_id}"
            echo "You need to update the launchpad configuration and add an additional level or deploy in the level0."
            echo "Or you do not have permissions to access the launchpad."
            echo
            echo "List of the other launchpad deployed"
            execute_with_backoff az storage account list \
                --subscription ${TF_VAR_tfstate_subscription_id} \
                --query "[?tags.tfstate=='${TF_VAR_level}'].{name:name,environment:tags.environment, launchpad:tags.launchpad}" -o table

            exit 0
        fi
    fi
}
