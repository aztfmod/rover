source ${script_path}/lib/terraform.sh

function tfstate_cleanup {

    find /tf/caf -name "backend.*.tf" -not -path '*/rover/scripts/*' -delete || true
    rm -rf -- "${landingzone_name}/backend.hcl.tf" || true
    rm -rf -- "${landingzone_name}/backend.hcl" || true
    rm -rf -- "${landingzone_name}/caf.auto.tfvars" || true
    rm -rf -- "${TF_DATA_DIR}/terraform.tfstate" || true

}

function tfstate_configure {
    echo "@tfstate_configure"

    case "${1}" in
        azurerm)
            echo "@calling tfstate_configure -- azurerm"
            rm -f -- ${landingzone_name}/backend.hcl.tf
            cp -f ${script_path}/backend.azurerm.tf ${landingzone_name}/backend.azurerm.tf
            ;;
        remote)
            echo "@calling tfstate_configure -- remote"
            rm -f -- ${landingzone_name}/backend.azurerm.tf
            cp -f ${script_path}/backend.hcl.tf ${landingzone_name}/backend.hcl.tf

            if [ ! -z ${TF_var_folder} ]; then
                rm -rf -- "${landingzone_name}/caf.auto.tfvars" || true
                find ${TF_var_folder} -name '*.tfvars' -type f | while read filename; do
                    command="cat ${filename} >> ${landingzone_name}/caf.auto.tfvars && printf '\n' >> ${landingzone_name}/caf.auto.tfvars"
                    debug ${command}
                    eval ${command}
                done

                terraform fmt ${landingzone_name}/caf.auto.tfvars
            fi

            export TF_VAR_workspace="${TF_VAR_environment}_${TF_VAR_level}_$(echo ${TF_VAR_tf_name} | cut -f 1 -d '.')"
            export TF_VAR_tfstate_organization=${TF_VAR_tf_cloud_organization}
            export TF_VAR_tfstate_hostname=${TF_VAR_tf_cloud_hostname}

            cat << EOF > ${landingzone_name}/backend.hcl
workspaces { name = "${TF_VAR_workspace}" }
hostname     = "${TF_VAR_tf_cloud_hostname}"
organization = "${TF_VAR_tf_cloud_organization}"
EOF

            ;;
        *)
            tfstate_cleanup
            error ${LINENO} "Error backend type not yet supported: ${gitops_terraform_backend_type}" 3001
            ;;
    esac

}

function terraform_init {
    echo "@calling terraform_init"

    case "${gitops_terraform_backend_type}" in
        azurerm)
            echo "@calling terraform_init -- azurerm"
            terraform_init_azurerm
            ;;
        remote)
            echo "@calling terraform_init -- remote"
            terraform_init_remote
            ;;
        *)
            error ${LINENO} "Error backend type not yet supported: ${gitops_terraform_backend_type}" 3002
            ;;
    esac

}

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

    tfstate_cleanup

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version 0.15 or greater"
            terraform -chdir=${landingzone_name} \
                init \
                -upgrade=true | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
            ;;
        *)
            terraform init \
                -get-plugins=true \
                -upgrade=true \
                ${landingzone_name} | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
            ;;
    esac

    RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

    case "${tf_action}" in
    "plan")
        echo "calling plan"
        plan
        ;;
    "apply")
        echo "calling apply"
        apply
        upload_tfstate
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
        echo "No more tfstate file"
        exit
        ;;
    *)
        other
        ;;
    esac

    tfstate_cleanup

    cd "${current_path}"

    if [ "$devops" != "true" ]; then
        clean_up_variables
        exit 0
    fi
}

function upload_tfstate {
    echo "@calling upload_tfstate"

    echo "Moving launchpad to the cloud"

    get_storage_id
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

function deploy_from_azurerm_state {
    echo "@calling deploy_from_azurerm_state"

    echo 'Connecting to the launchpad'
    cd ${landingzone_name}

    tfstate_configure ${gitops_terraform_backend_type}

    login_as_launchpad

    deploy_landingzone

    tfstate_cleanup

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
    tfstate_cleanup

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

function terraform_init_azurerm {

    rm -f -- ${landingzone_name}/backend.hcl.tf
    cp -f /tf/rover/backend.azurerm.tf ${landingzone_name}/backend.azurerm.tf

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform version ${terraform_version}"
            echo "Running Terraform init..."
            terraform -chdir=${landingzone_name} \
                init \
                -reconfigure \
                -backend=true \
                -upgrade \
                -backend-config storage_account_name=${TF_VAR_tfstate_storage_account_name} \
                -backend-config resource_group_name=${TF_VAR_tfstate_resource_group_name} \
                -backend-config container_name=${TF_VAR_workspace} \
                -backend-config key=${TF_VAR_tf_name} \
                -backend-config subscription_id=${TF_VAR_tfstate_subscription_id} | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
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
                ${landingzone_name} | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
            ;;
    esac

    RETURN_CODE=$?
    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform init (azurerm) " $RETURN_CODE
    fi
}

function plan {
    echo "@calling plan"

    plan_command=$(purge_command plan ${tf_command} $1)
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

    echo "Running Terraform plan..."

    case "${gitops_terraform_backend_type}" in
        azurerm)
            echo "@calling terraform_plan -- azurerm"
            case ${terraform_version} in
                *"15"* | *"1."*)
                    terraform -chdir=${landingzone_name} \
                        plan ${plan_command} \
                        -refresh=true \
                        -lock=false \
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
            ;;
        remote)
            echo "@calling terraform_plan -- remote"
            terraform -chdir=${landingzone_name} \
                plan \
                -refresh=true \
                -lock=false \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" | tee ${tf_output_file}
            ;;
        *)
            error ${LINENO} "Error backend type not yet supported: ${gitops_terraform_backend_type}" 3003
            ;;
    esac

    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform plan return code: ${RETURN_CODE}"

    if [ ! -z ${tf_plan_file} ]; then
        if [ -f "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" ]; then
            echo "Copying plan file to ${tf_plan_file}"
            cp "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" "${tf_plan_file}"
        fi
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

}

function apply {
    echo "@calling apply"

    terraform_apply

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

function show {
    echo "@calling show"

    show_command=$(purge_command show ${tf_command})
    echo "running terraform ${tf_action} with ${show_command}"

    echo " -TF_VAR_workspace: ${TF_VAR_workspace}"
    echo " -state: ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    echo " -plan:  ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"
    rm -f $STDERR_FILE

    cd ${landingzone_name}
    terraform init -upgrade
    terraform show ${show_command} | tee ${tf_output_file}

    warning "terraform show output file: ${tf_output_file}"

    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform ${tf_action} return code: ${RETURN_CODE}"

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform ${tf_action}" $RETURN_CODE
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
    echo "terraform destroy parameters: -chdir=${landingzone_name} apply -refresh=false $(parse_command_destroy_with_plan ${tf_command}) ${tf_approve} ${tf_plan_file}"

    tfstate_cleanup

    if [ "$1" == "remote" ]; then

        tfstate_configure ${gitops_terraform_backend_type}

        echo 'running terraform destroy remote'
        terraform_init_azurerm

        if [ -z ${tf_plan_file} ]; then
            echo "Plan not provided with -p or --plan so calling terraform plan"
            plan "-destroy"

            local tf_plan_file="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"
        fi

        RETURN_CODE=$? && echo "Line ${LINENO} - Terraform destroy return code ${RETURN_CODE}"

        case ${terraform_version} in
            *"15"* | *"1."*)
                echo "Terraform version 0.15 or greater"
                terraform -chdir=${landingzone_name} \
                    apply \
                    -refresh=false \
                    $(parse_command_destroy_with_plan ${tf_command}) ${tf_approve} \
                    "${tf_plan_file}"
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
                    -upgrade=true | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
                ;;
            *)
                terraform init \
                    -reconfigure=true \
                    -get-plugins=true \
                    -upgrade=true \
                    ${landingzone_name} | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
                ;;
        esac

        RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

        if [ -z ${tf_plan_file} ]; then
            echo "Plan not provided with -p or --plan so calling terraform plan"
            plan "-destroy"

            local tf_plan_file="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"
        fi

        echo "using tfstate from ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
        mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

        case ${terraform_version} in
            *"15"* | *"1."*)
                echo "Terraform version 0.15 or greater"
                terraform -chdir=${landingzone_name} \
                    apply \
                    $(parse_command_destroy_with_plan ${tf_command}) ${tf_approve} \
                    -refresh=false \
                    -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                    "${tf_plan_file}"
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
        --query "[?((tags.caf_tfstate=='${TF_VAR_level}' && tags.caf_environment=='${TF_VAR_environment}') || (tags.tfstate=='${TF_VAR_level}' && tags.environment=='${TF_VAR_environment}'))].{id:id}[0]" -o json | jq -r .id)

    if [[ -z ${id} ]] && [ "${caf_command}" != "launchpad" ]; then
        # Check if other launchpad are installed
        id=$(execute_with_backoff az storage account list \
            --subscription ${TF_VAR_tfstate_subscription_id} \
            --query "[?tags.tfstate=='${TF_VAR_level}'].{id:id}[0]" -o json | jq -r .id)

        if [[ -z ${id} ]]; then
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

            exit 1
        fi
    fi
}
