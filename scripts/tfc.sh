function deploy_tfc {

    echo "@calling_deploy_tfc"
    initialize_state_tfc

    case "${tf_action}" in
        "plan")
            echo "calling plan"
            plan_tfc
            ;;
        "apply")
            echo "calling plan and apply"
            plan_tfc
            apply_tfc
            ;;
        "validate")
            echo "calling validate"
            validate
            ;;
        "destroy")
            destroy_tfc
            ;;
        *)
            other
            ;;
    esac

    rm -rf backend.azurerm.tf

    cd "${current_path}"
}

function initialize_state_tfc {
    echo "@calling initialize_state for tfc/tfe"

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
            terraform -chdir=${landingzone_name} \
                init \
                -upgrade \
                -migrate-state \
                -backend-config=${landingzone_name}/backend.hcl | grep -P '^- (?=Downloading|Using|Finding|Installing)|^[^-]'
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

function plan_tfc {
    echo "@calling plan for tfc/tfe"

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

function apply_tfc {
    echo "@calling apply tfc/tfe"

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

function destroy_tfc {
    echo "@calling destroy tfc/tfe"

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
    case "${TF_backend_type}" in
        tfc)
            login_as_launchpad
            migrate_to_tfc
            ;;
        *)
            error ${LINENO} "Only migration from azurerm to Terraform Cloud or Enterprise is supported." 1
    esac

}

function migrate_to_tfc {
    tfstate_configure 'azurerm'
    terraform_init_remote_azurerm

    tfstate_configure 'tfc'
    initialize_state_tfc

    echo "Migration complete to TFC/TFE."
}
