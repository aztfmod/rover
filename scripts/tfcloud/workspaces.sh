
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
  if [[ "${gitops_agent_pool_execution_mode}" == "agent" ]]; then
    check_terraform_cloud_agent_exist
  fi

  # Check to see if the workspace already exists
  echo ""
  echo "Checking if workspace exists for ${TF_VAR_workspace}"
  response=$(workspace_get ${TF_VAR_workspace})
  export workspace_id=$response

  # Create workspace if it does not already exist
  if [[ "$workspace_id" == "null" ]]; then
    echo ""
    echo "Workspace does not exist. Creating it."

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/workspaces"
    body=$(make_curl_request -url "$url")
    export workspace=$(echo $body  | jq -r .data)

    jq_command=$(cat <<- EOF
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
              "global-remote-state": false,
            $(if [[ ${TF_CLOUD_WORKSPACE_ATTRIBUTES_ASSESSMENTS_ENABLED} ]]; then
              cat <<- AAA
              "assessments-enabled": ${TF_CLOUD_WORKSPACE_ATTRIBUTES_ASSESSMENTS_ENABLED:=false},
AAA
            fi)
              "structured-run-output-enabled": false,
            },
            $(if [[ ${TF_CLOUD_PROJECT_ID} ]]; then
              cat <<- EOT
              "relationships": {
                "project": {
                  "data": {
                    "id": "${TF_CLOUD_PROJECT_ID}"
                  }
                }
              },
EOT
            fi)
            "type": "workspaces"
          }
        }
      '
EOF
    )
    eval ${jq_command} | jq
    BODY=$(eval ${jq_command})
    METHOD="POST"

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

workspace_process_variable_prefixes() {

  local var_obj=""
  var_obj=$1

  IFS=',' read -r prefix varname description sensitive allowempty var_category <<< "$var_obj"
  debug "Checking prefix: $prefix"

  if [[ -n $(compgen -v "$prefix") ]]; then
    for var in $(compgen -A variable | grep "^$prefix"); do
      name="${var#$prefix}"
      value="${!var}"

      workspace_variable_create_update $name $name "$description" $sensitive $allowempty $var_category "$value"
    done
  else
    debug "There is no variables for the prefix: $prefix"
  fi
}

workspace_process_variable_rover() {

  local var_obj=""
  var_obj="$1"

  IFS=',' read -r key varname description sensitive allowempty var_category <<< "$var_obj"

  workspace_variable_create_update  $key $varname "$description" $sensitive $allowempty $var_category

}

workspace_variable_create_update() {

  key=$1
  varname=$2
  description=$3
  sensitive=$4
  allowempty=$5
  var_category=$6
  value=$7

  if [[ ! ${value} ]]; then
    value=$(env | grep $varname | cut -d= -f2)
  fi

  debug "key: $key"
  debug "value: $value"

  vars_workspace+=("$key")

  var_id=$(echo $vars | jq -r ".data[] | select(.attributes.key == \"$key\") | .id")
  current_value="$(echo $vars | jq -r ".data[] | select(.attributes.key == \"$key\") | .attributes.value")"

  if [[ "${current_value}" != "${value}" ]]; then

    if [[ "$allowempty" == "false" && -z "$value" ]];then
      error "$varname environment variable has not been set."
    else

      if [[ -z "$var_id" ]]; then
        action="Adding"

        BODY=$(jq -c -n \
            --arg type "vars" \
            --arg key "$key" \
            --arg value "$value" \
            --arg description "$description" \
            --arg workspace_id "${workspace_id}" \
            --arg sensitive "$sensitive" \
            --arg category "$var_category" \
            '
              {
                "data": {
                  "attributes": {
                    "key": $key,
                    "value": $value,
                    "description": $description,
                    "category": $category,
                    "sensitive": $sensitive
                  },
                  "type": $type,
                  "relationships": {
                    "workspace": {
                      "data": {
                        "type": "workspaces",
                        "id": $workspace_id
                      }
                    }
                  }
                }
              }
            '
          ) && debug " - body: $BODY"

        url="https://${TF_VAR_tf_cloud_hostname}/api/v2/vars"
        method="POST"

      else
        action="Updating"

        BODY=$(jq -c -n \
            --arg id $var_id \
            --arg type "vars" \
            --arg key "$key" \
            --arg value "$value" \
            --arg description "$description" \
            --arg sensitive "$sensitive" \
            --arg category "$var_category" \
            '
              {
                "data": {
                  "id": $id,
                  "attributes": {
                    "key": $key,
                    "value": $value,
                    "description": $description,
                    "category": $category,
                    "sensitive": $sensitive
                  },
                  "type": $type
                }
              }
            '
          ) && debug " - body: $BODY"

        url="https://${TF_VAR_tf_cloud_hostname}/api/v2/vars/${var_id}"
        method="PATCH"

      fi

      if [[ "$sensitive" == "true" ]]; then
        warning "${action} variable $key: *********** [$description]"
      else
        warning "${action} variable $key: $value [$description]"
      fi

      result=$(make_curl_request -url "$url" -options "--request ${method}" -data "${BODY}")
    fi
  else
    debug "Variable '$key' is already set to '$value'"
  fi
}

workspace_variable_delete() {

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/${workspace_id}/vars"
  debug $url
  vars=$(make_curl_request -url "$url")
  data=$(echo $vars | jq -c .data)

  while IFS= read -r var; do

    debug "$(echo $var | jq)"
    found=false

    ws_key="$(echo $var | jq -r .attributes.key)"

    for key in "${vars_workspace[@]}"; do
      if [[ "$key" == "$ws_key" ]]; then
        found=true
        break
      fi
    done

    # Check if the value was found in the array
    if $found; then
      debug "The array contains the value: $ws_key"
    else
      debug "The array does not contain the value: $ws_key"
      ws_var_id=$(echo $var | jq -r .id)
      url="https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/${workspace_id}/vars/${ws_var_id}"
      debug "$url"
      vars=$(make_curl_request -url "$url" -options "--request DELETE")
      debug "Variable '$key' deleted from workspace ${TF_VAR_workspace} (${workspace_id})"
    fi

  done <<< $(echo ${data} | jq -c '.[]')

}