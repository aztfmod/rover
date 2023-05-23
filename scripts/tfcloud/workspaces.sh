
workspace_get() {
  debug "@calling workspace_get for ${1}"

  local result=""
  local workspace_name=${1}

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/workspaces/${workspace_name}"
  body=$(make_curl_request -url "$url" -gracefully_continue)
  echo $body | jq -r '.data.id'
}


verify_create_workspace() {
  information "@calling verify_create_workspace for ${TF_VAR_workspace}"

  get_remote_token
  check_terraform_cloud_agent_exist

  # Check to see if the workspace already exists
  echo ""
  echo "Checking if workspace exists"
  response=$(workspace_get ${TF_VAR_workspace})
  export workspace_id=$response

  # Create workspace if it does not already exist
  if [[ "$workspace_id" == "null" ]]; then
    echo ""
    echo "Workspace does not exist. Creating it."

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/workspaces"
    body=$(make_curl_request -url "$url")
    export workspace=$(echo $body  | jq -r .data)

    jq_command=$(cat <<-EOF
    jq -c -n \
      '
        {
          "data": {
            "attributes": {
              "name": "${TF_VAR_workspace}",
              $(if [[ ${gitops_agent_pool_name} || ${TF_CLOUD_AGENT_POOL_ID} ]]; then
                  echo "\"agent-pool-id\": \"${TF_CLOUD_AGENT_POOL_ID}\","
                fi
              )
              "execution-mode": "${gitops_agent_pool_execution_mode}",
              "global-remote-state": false
            },
            "type": "workspaces"
          }
        }
      '
EOF
    )
    eval ${jq_command}
    BODY=$(eval ${jq_command})

    # if [[ "$workspace_id" == "null" ]]; then
      METHOD="POST"
    # else
    #   export workspace_id=$(echo ${workspace} | jq -r .[0].id)
    #   METHOD="PATCH"
    #   url="${url}/${workspace_id}"
    # fi

    echo ${BODY}
    echo ${url}

    echo "Trigger api call."

    body=$(make_curl_request -url "$url" -options "--request ${METHOD} --data '${BODY}'")
    echo $body

    export workspace_id=$(echo $body | jq -r .data.id)
    echo "Workspace has been created with id: ${workspace_id}"

    if [ "${gitops_agent_pool_execution_mode}" == "remote" ]; then
      information "Agent pool: ${agent_pool} for workspace ${TF_VAR_workspace} set to execution mode: ${gitops_agent_pool_execution_mode}"
    else
      information "workspace ${TF_VAR_workspace} set to execution mode: ${gitops_agent_pool_execution_mode}"
    fi
  else
    echo ""
    echo "Workspace already created. (${workspace_id})"
  fi
}

workspace_remote_state_consumers_is_set() {
  debug "@calling workspace_remote_state_consumers_is_set"

  # Need to retrieve the workspace id for the remote workspace
  local result=""
  local remote_workspace_id="${1}"
  local workspace_id="${2}"

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/workspaces/${remote_workspace_id}/relationships/remote-state-consumers"
  result=$(make_curl_request -url "$url"  -gracefully_continue)
  echo $result | jq -r ".data[] | select (.id==\"${workspace_id}\")"

}

workspace_remote_state_consumers_add() {
  debug "@calling workspace_remote_state_consumers_add"

  local remote_workspace_id="${1}"
  local workspace_id="${2}"

  BODY=$(jq -c -n \
      --arg type "workspaces" \
      --arg id "$workspace_id" \
      '
        {
          "data": {
            "id": $id,
            "type": $type
          }
        }
      '
    ) && debug " - body: $BODY"

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/${remote_workspace_id}/relationships/remote-state-consumers"
  method="POST"

  result=$(make_curl_request -url "$url" -options "--request ${method}" -data "${BODY}")
}