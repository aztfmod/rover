
parse_parameters() {

  while (( "$#" )); do
    case "${1}" in
      --walkthrough)
        export caf_command="walkthrough"
        shift 1
        ;;
      --clone|--clone-branch|--clone-folder|--clone-destination|--clone-folder-strip)
        export caf_command="clone"
        process_clone_parameter $@
        shift 2
        ;;
      -lz|--landingzone)
        export caf_command="landingzone"
        export landingzone_name=$(parameter_value --landingzone ${2})
        export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename ${landingzone_name}).tfstate"}
        export lz_folder=${2}
        shift 2
        ;;
      -lp|--log-path)
        export log_folder_path=${2}
        shift 2
        ;;
      -c|--cloud)
        export cloud_name=$(parameter_value --cloud ${2})
        shift 2
        ;;
      -d|--debug)
        export debug_mode="true"
        set_log_severity DEBUG
        shift 1
        ;;
      -log-severity)
        set_log_severity $2
        shift 2
        ;;
      -stack)
        export stack_name=${2}
        shift 2
        ;;
      -a|--action)
        export tf_action=$(parameter_value --action "${2}")
        shift 2
        ;;
      --clone-launchpad)
        export caf_command="clone"
        export landingzone_branch=${landingzone_branch:="master"}
        export clone_launchpad="true"
        export clone_landingzone="false"
        echo "cloning launchpad"
        shift 1
        ;;
      workspace)
        shift 1
        export caf_command="workspace"
        ;;
      landingzone)
        shift 1
        export caf_command="landingzone_mgmt"
        ;;
      login)
        shift 1
        export caf_command="login"
        ;;
      validate | ci)
        shift 1
        export caf_command="ci"
        export devops="true"
        ;;
      ignite)
        shift 1
        export caf_command="ignite"
        ;;
      init)
        shift 1
        export caf_command="init"
        ;;
      --location)
        export location=${2}
        shift 2
        ;;
      --playbook | -playbook)
        export caf_ignite_playbook=${2}
        shift 2
        ;;
      -e)
        export caf_ignite_environment+="${1} ${2} "
        shift 2
        ;;
      purge)
        purge
        ;;
      deploy | cd)
        export cd_action=${2}
        export TF_VAR_level="all"
        export caf_command="cd"
        export devops="true"
        len=$#
        if [ "$len" == "1" ]; then
          shift 1
        else
          shift 2
        fi

        ;;
      test)
        shift 1
        export caf_command="test"
        export devops="true"
        ;;
      -sc|--symphony-config)
        export symphony_yaml_file=$(parameter_value --symphony-config ${2})
        shift 2
        ;;
      -ct|--ci-task-name)
        export ci_task_name=$(parameter_value --ci-task-name ${2})
        export symphony_run_all_tasks=false
        shift 2
        ;;
      -b|--base-dir)
        export base_directory=$(parameter_value --base-dir ${2})
        shift 2
        ;;
      -tfc|--tfc|-remote|--remote)
        shift 1
        export gitops_terraform_backend_type="remote"
        ;;
      -backend-type-hybrid)
        export backend_type_hybrid=${2}
        shift 2
        ;;
      -remote_organization|-tf_cloud_organization|--remote_organization|--tf_cloud_organization)
        export TF_VAR_tf_cloud_organization="${2}"
        export gitops_terraform_backend_type="remote"
        shift 2
        ;;
      -tf_cloud_hostname|--tf_cloud_hostname|-remote_hotname)
        export TF_VAR_tf_cloud_hostname="${2}"
        export gitops_terraform_backend_type="remote"
        shift 2
        ;;
      -tf_cloud_force_run)
        export tf_cloud_force_run=true
        shift 1
        ;;
      -t|--tenant)
        export tenant=$(parameter_value --tenant ${2})
        shift 2
        ;;
      -s|--subscription)
        export subscription=$(parameter_value --subscription ${2})
        shift 2
        ;;
      logout)
          shift 1
          export caf_command="logout"
          ;;
      -tfstate)
        export TF_VAR_tf_name=$(parameter_value -tfstate ${2})
        if [ ${TF_VAR_tf_name##*.} != "tfstate" ]; then
            echo "tfstate name extension must be .tfstate"
            exit 50
        fi
        export TF_VAR_tf_plan="${TF_VAR_tf_name%.*}.tfplan"
        shift 2
        ;;
      -env|--environment)
        export TF_VAR_environment=$(parameter_value --environment ${2})
        shift 2
        ;;
      -launchpad)
        export caf_command="launchpad"
        export TF_DATA_DIR=${TF_DATA_DIR:="$(echo ~)/.terraform.cache/launchpad"}
        shift 1
        ;;
      -o|--output)
        tf_output_file=$(parameter_value --output ${2})
        shift 2
        ;;
      -p|--plan)
        tf_plan_file=$(parameter_value '-p or --plan' ${2})
        shift 2
        ;;
      -w|--workspace)
        export TF_VAR_workspace=$(parameter_value '--workspace' ${2})
        shift 2
        ;;
      -l|-level)
        export TF_VAR_level=$(parameter_value '-level' ${2})
        shift 2
        ;;
      -skip-permission-check)
        export skip_permission_check=true
        shift 1
        ;;
      -var-folder)
        expand_tfvars_folder $(parameter_value '-var-folder' ${2})
        export TF_var_folder="${2}"
        var_folder_set=true
        shift 2
        ;;
      -tfstate_subscription_id|--tfstate_subscription_id)
        export TF_VAR_tfstate_subscription_id=$(parameter_value -tfstate_subscription_id ${2})
        shift 2
        ;;
      -target_subscription)
        export target_subscription=$(parameter_value -target_subscription ${2})
        shift 2
        ;;
      --impersonate-sp-from-keyvault-url)
        export sp_keyvault_url=$(parameter_value --impersonate-sp-from-keyvault-url ${2})
        debug "Impersonate from keyvault ${sp_keyvault_url}"
        shift 2
        ;;
      -bootstrap)
        export caf_command="bootstrap"
        shift 1
        ;;
      -bootstrap-scenario-file | -bootstrap-script)
        export bootstrap_script=${2}
        shift 2
        ;;
      -aad-app-name)
        export aad_app_name=${2}
        shift 2
        ;;
      -gitops-terraform-backend-type)
        export gitops_terraform_backend_type=${2}
        shift 2
        ;;
      -gitops-number-runners)
        export gitops_number_runners=${2}
        shift 2
        ;;
      -gitops-pipelines)
        export gitops_pipelines=${2}
        shift 2
        ;;
      -gitops-pipelines-compute)
        export gitops_pipelines_compute=${2}
        shift 2
        ;;
      # -gitops-agent-pool-type)
      #   export gitops_agent_pool_execution_mode=${2}
      #   if [ ${gitops_agent_pool_execution_mode} = "tfcloud" ]; then
      #     export gitops_agent_pool_execution_mode="agent"
      #   fi
      #   shift 2
      #   ;;
      -gitops-agent-pool-execution-mode)
        export gitops_agent_pool_execution_mode=${2}
        shift 2
        ;;
      -gitops-agent-pool-name)
        export gitops_agent_pool_name=${2}
        shift 2
        ;;
      -gitops-agent-pool-id)
        export gitops_agent_pool_id=${2}
        shift 2
        ;;
      -subscription-deployment-mode)
        export subscription_deployment_mode=${2}
        shift 2
        ;;
      -sub-management)
        export sub_management=${2}
        shift 2
        ;;
      -sub-connectivity)
        export sub_connectivity=${2}
        shift 2
        ;;
      -sub-identity)
        export sub_identity=${2}
        shift 2
        ;;
      -sub-security)
        export sub_security=${2}
        shift 2
        ;;
      -arm_use_oidc)
        export ARM_USE_OIDC=true
        shift 1
        ;;
      *) # preserve positional arguments
        PARAMS+="${1} "
        shift
        ;;
    esac
  done
}