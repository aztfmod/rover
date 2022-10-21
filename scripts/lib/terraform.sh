
function terraform_plan {
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


    echo "@calling terraform_plan -- ${gitops_terraform_backend_type}"
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

function terraform_apply {
    debug "@calling terraform_apply"

    information "running terraform apply - ${gitops_terraform_backend_type}"
    rm -f $STDERR_FILE

    if [[ -z ${tf_plan_file} ]] && [ "${gitops_terraform_backend_type}" = "azurerm" ]; then
        echo "Plan not provided with -p or --plan so calling terraform plan"
        terraform_plan

        local tf_plan_file="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"
    fi

    echo "Running Terraform apply with plan ${tf_plan_file}"

    case ${terraform_version} in
        *"15"* | *"1."*)
            echo "Terraform apply (${gitops_terraform_backend_type}) with version ${terraform_version}"

            case "${gitops_terraform_backend_type}" in
                azurerm)
                    terraform -chdir=${landingzone_name} \
                        apply \
                        -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                        "${tf_plan_file}" | tee ${tf_output_file}
                    ;;
                remote)
                    terraform -chdir=${landingzone_name} \
                        apply \
                        -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" | tee ${tf_output_file}
                    ;;
            esac
            ;;
        *)
            terraform apply \
                -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
                "${tf_plan_file}" | tee ${tf_output_file}
            ;;
    esac

    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform apply return code: ${RETURN_CODE}"

    if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "Error running terraform apply" $RETURN_CODE
    else
      export text_log_status="terraform apply succeeded"
    fi

}