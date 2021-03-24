function deploy_tfc {

    echo "@calling_deploy_tfc"
    initialize_state_tfc
    # case "${id}" in
    #     "null")
    #         echo "No launchpad found."
    #         if [ "${caf_command}" == "launchpad" ]; then
    #             if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
    #                 echo "Recover from an un-finished previous execution"
    #                 if [ "${tf_action}" == "destroy" ]; then
    #                     destroy_tfc
    #                 else
    #                     initialize_state_tfc
    #                 fi
    #             else
    #                 rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    #                 if [ "${tf_action}" == "destroy" ]; then
    #                     echo "There is no launchpad in this subscription"
    #                 else
    #                     echo "Deploying from scratch the launchpad"
    #                     rm -rf "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    #                     initialize_state_tfc
    #                 fi
    #                 exit
    #             fi
    #         else
    #             error ${LINENO} "You need to initialise a launchpad first with the command \n
    #             rover /tf/caf/landingzones/launchpad [plan | apply | destroy] -launchpad" 1000
    #         fi
    #     ;;
    #     '')
    #         #error ${LINENO} "you must login to an Azure subscription first or logout / login again" 2
    #         initialize_state_tfc
    #     *)

    #     # Get the launchpad version
    #     caf_launchpad=$(az storage account show --ids $id -o json | jq -r .tags.launchpad)
    #     echo ""
    #     echo "${caf_launchpad} already installed"
    #     echo ""

    #     if [ -e "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" ]; then
    #         echo "Recover from an un-finished previous execution"
    #         if [ "${tf_action}" == "destroy" ]; then
    #             if [ "${caf_command}" == "landingzone" ]; then
    #                 login_as_launchpad_tfc
    #             fi
    #             destroy
    #         else
    #             initialize_state_tfc
    #         fi
    #         exit 0
    #     else
    #         case "${tf_action}" in
    #         "destroy")
    #             destroy_from_remote_state_tfc
    #             ;;
    #         "plan"|"apply"|"validate"|"import"|"output"|"taint"|"state list")
    #             deploy_from_remote_state_tfc
    #             ;;
    #         *)
    #             display_instructions
    #             ;;
    #         esac
    #     fi
    #     ;;
    # esac


}

function initialize_state_tfc {
    echo "@calling initialize_state for tfc/tfe"

    echo "Installing launchpad from ${landingzone_name}"
    cd ${landingzone_name}

    sudo rm -f -- ${landingzone_name}/backend.azurerm.tf
    sudo rm -f -- ${landingzone_name}/backend.hcl.tf
    rm -f -- "${TF_DATA_DIR}/terraform.tfstate"

    cp -f /tf/rover/backend.hcl.tf ${landingzone_name}/backend.hcl.tf

    get_logged_user_object_id

    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename $(pwd)).tfstate"}
    export TF_VAR_tf_plan=${TF_VAR_tf_plan:="$(basename $(pwd)).tfplan"}
    export STDERR_FILE="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$(basename $(pwd))_stderr.txt"

    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

    terraform init \
        -get-plugins=true \
        -upgrade=true \
        -reconfigure \
        -backend-config=${landingzone_name}/backend.hcl \
        ${landingzone_name}

    RETURN_CODE=$? && echo "Line ${LINENO} - Terraform init return code ${RETURN_CODE}"

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

function plan_tfc {
    echo "@calling plan for tfc/tfe"

    echo "running terraform plan with ${tf_command}"
    echo " -TF_VAR_workspace: ${TF_VAR_workspace}"
    echo " -state: ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}"
    echo " -plan:  ${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}"

    pwd
    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"


    rm -f $STDERR_FILE

    terraform plan ${tf_command} \
        -refresh=true \
        -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        -out="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" $PWD 2>$STDERR_FILE | tee ${tf_output_file}

    if [ ! -z ${tf_output_plan_file} ]; then
        echo "Copying plan file to ${tf_output_plan_file}"
        cp "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" "${tf_output_plan_file}"
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

function login_as_launchpad_tfc {
    echo "@calling login_as_launchpad tfc/tfe"

    echo ""
    echo "Getting launchpad coordinates from subscription: ${TF_VAR_tfstate_subscription_id}"

    export keyvault=$(az keyvault list --subscription ${TF_VAR_tfstate_subscription_id} --query "[?tags.tfstate=='${TF_VAR_level}' && tags.environment=='${TF_VAR_environment}']" -o json | jq -r .[0].name)

    echo " - keyvault_name: ${keyvault}"

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

function apply_tfc {
    echo "@calling apply tfc/tfe"

    echo 'running terraform apply'
    rm -f $STDERR_FILE

    terraform apply \
        -state="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_name}" \
        "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/${TF_VAR_tf_plan}" 2>$STDERR_FILE | tee ${tf_output_file}

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