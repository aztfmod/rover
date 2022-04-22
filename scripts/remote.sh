function deploy_remote {
    echo "@calling deploy_remote"

    initialize_state_remote

    case "${tf_action}" in
        "plan")
            echo "calling plan"
            plan_remote
            ;;
        "apply")
            echo "calling plan and apply"
            plan_remote
            apply_remote
            ;;
        "validate")
            echo "calling validate"
            validate
            ;;
        "destroy")
            destroy_remote
            ;;
        *)
            other
            ;;
    esac

    rm -rf backend.azurerm.tf

    cd "${current_path}"
}

function get_remote_token {
    echo "@calling get_remote_token"

    if [ -z "${REMOTE_credential_path_json}" -o -z "${REMOTE_hostname}" ]
    then
        error ${LINENO} "You must provide REMOTE_credential_path_json and REMOTE_hostname'." 1
    fi

    echo "Getting token from ${REMOTE_credential_path_json} for ${REMOTE_hostname}"

    export REMOTE_ORG_TOKEN=${REMOTE_ORG_TOKEN:=$(cat ${REMOTE_credential_path_json} | jq -r .credentials.\"${REMOTE_hostname}\".token)}

    if [ -z "${REMOTE_ORG_TOKEN}" ]; then
        error ${LINENO} "You must provide either a REMOTE_ORG_TOKEN token or run 'terraform login'." 1
    fi
}

function create_workspace {
    echo "@calling create_workspace"

    get_remote_token

    workspace=$(curl -s \
        --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request GET \
        https://${REMOTE_hostname}/api/v2/organizations/${REMOTE_organization}/workspaces?search%5Bname%5D=${TF_VAR_workspace}" | jq -r .data)

    if [ "${workspace}" == "[]" ]; then

    CONFIG_PATH="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    cat <<EOF > ${CONFIG_PATH}/payload.json
{
  "data": {
    "attributes": {
      "name": "${TF_VAR_workspace}",
      "execution-mode": "local"
    },
    "type": "workspaces"
  }
}
EOF

    echo "Trigger workspace creation."

    curl -s \
        --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request POST \
        --data @${CONFIG_PATH}/payload.json \
        https://${REMOTE_hostname}/api/v2/organizations/${REMOTE_organization}/workspaces

    fi
}

function initialize_state_remote {
    echo "@calling initialize_state_remote"

    echo "Installing launchpad from ${landingzone_name}"
    cd ${landingzone_name}

    sudo rm -f -- ${landingzone_name}/backend.azurerm.tf

    cp -f /tf/rover/backend.hcl.tf ${landingzone_name}/backend.hcl.tf

    get_logged_user_object_id

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"

    mkdir -p "${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"


    case "${tf_action}" in
        "migrate")
            migrate_command=$(purge_command migrate ${tf_command} $1)
            create_workspace
            terraform -chdir=${landingzone_name} \
                init ${migrate_command} \
                -upgrade \
                -migrate-state \
                -backend-config=${landingzone_name}/backend.hcl  | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
            ;;
        *)
            rm -f -- "${TF_DATA_DIR}/${TF_VAR_environment}/terraform.tfstate"
            terraform -chdir=${landingzone_name} \
                init \
                -upgrade \
                -reconfigure \
                -backend-config=${landingzone_name}/backend.hcl | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
            ;;
    esac

    RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"


}

function plan_remote {
    echo "@calling plan_remote"

    echo "running terraform plan with ${tf_command}"
    echo " -TF_VAR_workspace: ${TF_VAR_workspace}"
    echo " -state: ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    echo " -plan:  ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"

    pwd
    mkdir -p "${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"


    rm -f $STDERR_FILE

    terraform plan ${tf_command} \
        -refresh=true \
        -state="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        -out="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" $PWD 2>$STDERR_FILE | tee ${tf_output_file}

    if [ ! -z ${tf_plan_file} ]; then
        echo "Copying plan file to ${tf_plan_file}"
        cp "${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" "${tf_plan_file}"
    fi

    RETURN_CODE=$? && echo "Terraform plan return code: ${RETURN_CODE}"

    if [ -s $STDERR_FILE ]; then
        if [ ${tf_output_file+x} ]; then cat $STDERR_FILE >> ${tf_output_file}; fi
        echo "Terraform returned errors:"
        cat $STDERR_FILE
        RETURN_CODE=2000
    fi

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform plan" $RETURN_CODE
    fi
}

function apply_remote {
    echo "@calling apply_remote"

    echo 'running terraform apply'
    rm -f $STDERR_FILE

    terraform apply \
        -state="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        "${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" 2>$STDERR_FILE | tee ${tf_output_file}

    RETURN_CODE=$? && echo "Terraform apply return code: ${RETURN_CODE}"

    if [ -s $STDERR_FILE ]; then
        if [ ${tf_output_file+x} ]; then cat $STDERR_FILE >> ${tf_output_file}; fi
        echo "Terraform returned errors:"
        cat $STDERR_FILE
        RETURN_CODE=2001
    fi

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform apply" $RETURN_CODE
    fi

}

function destroy_remote {
    echo "@calling destroy_remote"

    echo 'running terraform destroy'
    rm -f $STDERR_FILE

    terraform destroy \
      -refresh=false \
      -auto-approve 2>$STDERR_FILE | tee ${tf_output_file}

    RETURN_CODE=$? && echo "Terraform apply return code: ${RETURN_CODE}"

    if [ -s $STDERR_FILE ]; then
        if [ ${tf_output_file+x} ]; then cat $STDERR_FILE >> ${tf_output_file}; fi
        echo "Terraform returned errors:"
        cat $STDERR_FILE
        RETURN_CODE=2001
    fi

    if [ $RETURN_CODE != 0 ]; then
        error ${LINENO} "Error running terraform apply" $RETURN_CODE
    fi

}

function migrate {
    case "${REMOTE_backend_type}" in
        remote)
            login_as_launchpad
            migrate_to_remote
            ;;
        *)
            error ${LINENO} "Only migration from azurerm to Terraform Cloud or Enterprise is supported." 1
    esac

}

function migrate_to_remote {
    tfstate_configure 'azurerm'
    terraform_init_remote_azurerm

    tfstate_configure 'remote'
    initialize_state_remote

    echo "Migration complete to remote."
}
