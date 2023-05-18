source ${script_path}/lib/aad_constants.sh
source ${script_path}/lib/github.com.sh
source ${script_path}/lib/azure_ad.sh

for script in ${script_path}/tfcloud/*.sh; do
  source "$script"
done

bootstrap() {
  information "@calling bootstrap"

  principalId=$(get_logged_in_user_object_id)

  if [ -z "${principalId}" ]; then
    information "You need to login to the Azure subscription where the CAF Launchpad will be deployed."
    exit 1
  else
    export tenant_id=$(az account show --query tenantId -o tsv)
  fi

  assert_sessions

  if  [ ! -z ${aad_app_name} ]; then
    create_federated_identity ${aad_app_name}
  fi

  if [ ! -z ${gitops_pipelines} ]; then
    process_gitops_agent_pool ${gitops_agent_pool_execution_mode}
  fi

  if [ ! -z ${bootstrap_script} ]; then
    register_rover_context
    ${bootstrap_script} "topology_file=${caf_ignite_playbook}" "GITOPS_SERVER_URL=${GITOPS_SERVER_URL}" "RUNNER_NUMBERS=${gitops_number_runners}" "gitops_agent=${gitops_agent_pool_execution_mode}" "ROVER_AGENT_DOCKER_IMAGE=${ROVER_AGENT_DOCKER_IMAGE}" "subscription_deployment_mode=${subscription_deployment_mode}" "sub_management=${sub_management}" "sub_connectivity=${sub_connectivity}" "sub_identity=${sub_identity}" "sub_security=${sub_security}" "gitops_pipelines=${gitops_pipelines}" "TF_VAR_environment=${TF_VAR_environment}" "bootstrap_sp_object_id=${sp_object_id}"
  fi

  information "Done."
}

assert_sessions() {
  information "@calling assert_sessions for ${gitops_terraform_backend_type}"

  case "${gitops_terraform_backend_type}" in
    "azurerm")
      assert_gitops_session "${gitops_pipelines}"
      ;;
    "remote")
      assert_gitops_session "tfcloud"
      assert_gitops_session "${gitops_pipelines}"
      ;;
    "*")
      error ${LINENO} "${gitops_terraform_backend_type} not supported yet."
      ;;
  esac
}

assert_gitops_session() {
  information "@call assert_gitops_session for ${1}"

  case "${1}" in
    "github")
      check_github_session
      ;;
    "tfcloud")
      GITOPS_SERVER_URL="https://${TF_VAR_tf_cloud_hostname}"
      check_terraform_session
      ;;
    "*")
      error ${LINENO} "Federated credential not supported yet for ${1}. You can submit a pull request"
      ;;
  esac

}


process_gitops_agent_pool() {
  information "@call process_gitops_agent_pool for ${1}"

  case "${1}" in
    "github")
      debug "github"
      export docker_hub_suffix="github"

      ;;
    "tfcloud")
      debug "tfcloud"
      export docker_hub_suffix="tfc"

      if [ ! -z ${gitops_agent_pool_name} ]; then
        process_terraform_cloud_agent_pool ${gitops_agent_pool_name}
      elif [ ! -z ${gitops_agent_pool_id} ]; then
        error ${LINENO} "Support of the attribute coming soon."
      else
        error ${LINENO} "You must specify the agent pool name to create (-gitops-agent-pool-name) or to re-use (-gitops-agent-pool-id)"
      fi

      ;;
    *)
      echo "Gitops pipelines compute '${1}' is not supported. Only 'aci' at the moment. You can submit a pull request"
      exit 1
  esac

}

register_rover_context() {
  information "@call register_rover_context"

  ROVER_AGENT_TAG=${ROVER_AGENT_VERSION:="1.2"}
  ROVER_AGENT_DOCKER_IMAGE=$(curl -s https://hub.docker.com/v2/repositories/aztfmod/rover-agent/tags | jq -r ".results | sort_by(.tag_last_pushed) | reverse  | map(select(.name | contains(\"${docker_hub_suffix}\") ) | select(.name | contains(\"${ROVER_AGENT_TAG}\") ) ) | .[0].name")

  cd /tf/caf/landingzones
  GIT_REFS=$(git show-ref | grep $(git rev-parse HEAD) | awk '{print $2}' | head -n 1)
  GIT_URL=$(git remote get-url origin)


  if [ "${gitops_agent_pool_execution_mode}" != "local" ];then
    register_gitops_secret ${gitops_pipelines} "ROVER_AGENT_DOCKER_IMAGE" ${ROVER_AGENT_DOCKER_IMAGE}
    register_gitops_secret ${gitops_pipelines} "CAF_GITOPS_TERRAFORM_BACKEND_TYPE" ${gitops_terraform_backend_type}
    register_gitops_secret ${gitops_pipelines} "CAF_BACKEND_TYPE_HYBRID" ${backend_type_hybrid}

    if [ ! -z ${ARM_USE_OIDC} ]; then
      register_gitops_secret ${gitops_pipelines} "ARM_USE_OIDC" ${ARM_USE_OIDC}
    fi

    if [ "${subscription_deployment_mode}" = "multi_subscriptions" ]; then
      register_gitops_secret ${gitops_pipelines} "AZURE_MANAGEMENT_SUBSCRIPTION_ID" ${sub_management}
      register_gitops_secret ${gitops_pipelines} "AZURE_CONNECTIVITY_SUBSCRIPTION_ID" ${sub_connectivity}
      register_gitops_secret ${gitops_pipelines} "AZURE_IDENTITY_SUBSCRIPTION_ID" ${sub_identity}
      register_gitops_secret ${gitops_pipelines} "AZURE_SECURITY_SUBSCRIPTION_ID" ${sub_security}
    else
      register_gitops_secret ${gitops_pipelines} "AZURE_MANAGEMENT_SUBSCRIPTION_ID" ${sub_management}
      register_gitops_secret ${gitops_pipelines} "AZURE_CONNECTIVITY_SUBSCRIPTION_ID" ${sub_management}
      register_gitops_secret ${gitops_pipelines} "AZURE_IDENTITY_SUBSCRIPTION_ID" ${sub_management}
      register_gitops_secret ${gitops_pipelines} "AZURE_SECURITY_SUBSCRIPTION_ID" ${sub_management}
    fi
  fi

}

#
# Register secrets for pipelines
#
register_gitops_secret() {
  debug "@call register_gitops_secret for ${1}/${2}"

  # back to the configuration repository
  cd /tf/caf

# ${1} gitops pipeline being used
# ${2} secret name
# ${3} secret value

  case "${1}" in
    "github")
      debug "github"
      register_github_secret ${2} ${3}
      ;;
    *)
      echo "Register gitops secret not supported yet for ${1}. You can submit a pull request"
      exit 1
  esac

}

create_gitops_federated_credentials() {
  debug "@call create_gitops_federated_credentials for ${1} ${2}"

# ${1} gitops pipeline being used
# ${2} azure ad application name


  case "${1}" in
    "github")
      debug "github"
      create_federated_credentials "github-${git_project}-pull_request" "repo:${git_org_project}:pull_request" "${2}"
      create_federated_credentials "github-${git_project}-refs-heads-main" "repo:${git_org_project}:ref:refs/heads/main" "${2}"
      create_federated_credentials "github-${git_project}-refs-heads-bootstrap" "repo:${git_org_project}:ref:refs/heads/bootstrap" "${2}"
      create_federated_credentials "github-${git_project}-refs-heads-end2end" "repo:${git_org_project}:ref:refs/heads/end2end" "${2}"
      ;;
    *)
      echo "Create a federated secret not supported yet for ${1}. You can submit a pull request"
      exit 1
  esac

}