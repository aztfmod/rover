check_terraform_session() {
  debug "tfcloud"

  if [ -e "${REMOTE_credential_path_json}" ]; then
    if [ -z ${TF_VAR_tf_cloud_hostname} ]; then
      token=$(cat ${REMOTE_credential_path_json})
      export TF_VAR_tf_cloud_hostname=$(echo ${token} | jq -r '.credentials | keys_unsorted[] as $k | {$k} | .k ')
    fi
  else
    error ${LINENO} "You need to login Terraform Cloud or Enterprise using 'terraform login'"
  fi

  if [ -z ${TF_VAR_tf_cloud_organization} ]; then
    error ${LINENO} " When you connect to Terraform Cloud or Enterprise you must set the organization name with the attribute (-TF_VAR_tf_cloud_organization"
  fi
  success "Connected to Terraform: ${TF_VAR_tf_cloud_hostname}/${TF_VAR_tf_cloud_organization}"
}

get_remote_token() {
    information "@calling get_remote_token"

    if [ -z "${REMOTE_credential_path_json}" -o -z "${TF_VAR_tf_cloud_hostname}" ]; then
      error ${LINENO} "You must provide REMOTE_credential_path_json and TF_VAR_tf_cloud_hostname'." 1
    fi

    information "Getting token from ${REMOTE_credential_path_json} for ${TF_VAR_tf_cloud_hostname}"

    export REMOTE_ORG_TOKEN=${REMOTE_ORG_TOKEN:=$(cat ${REMOTE_credential_path_json} | jq -r .credentials.\"${TF_VAR_tf_cloud_hostname}\".token)}

    if [ -z "${REMOTE_ORG_TOKEN}" ]; then
      error ${LINENO} "You must provide either a REMOTE_ORG_TOKEN token or run 'terraform login'. You must provide a Team token not an Organization token." 1
    fi
}

check_terraform_cloud_agent_exist() {
  information "@calling check_terraform_cloud_agent_exist ${gitops_agent_pool_name}"

  information ${TF_VAR_tf_cloud_hostname}
  information ${TF_VAR_tf_cloud_organization}

  if [[ -n ${gitops_agent_pool_name} ]]; then

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/agent-pools"
    body=$(make_curl_request -url "$url" -gracefully_continue)
    result=$(echo $body | jq -r ".data[] | select (.attributes.name == \"${gitops_agent_pool_name}\") | .id")

  elif [[ -n ${gitops_agent_pool_id} ]]; then

    # Checking the agent pool exists
    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/agent-pools/${gitops_agent_pool_id}"
    body=$(make_curl_request -url "$url" -gracefully_continue)
    result="$gitops_agent_pool_id"

  else
    error "You must set -gitops-agent-pool-id or -gitops-agent-pool-name when -gitops-agent-pool-execution-mode is set to agent."
  fi

  echo $result

  if [ "${result}" = "" ]; then
    # false
    error ${LINENO} "Cannot retrieve the agent pool details with the provided REMOTE_ORG_TOKEN"
  else
    export TF_CLOUD_AGENT_POOL_ID="${result}"
  fi

}

generate_agent_pool_name() {

  if [ -z ${TF_VAR_level} ]; then
    agent_pool="${1}"
  else
    agent_pool="${TF_VAR_level}_${1}"
  fi

  echo ${agent_pool}
}

process_terraform_cloud_agent_pool() {

    agent_pool=$(generate_agent_pool_name ${1})

    information "@calling process_terraform_cloud_agent_pool for ${agent_pool}"

# ${1} agent pool name

    if ! check_terraform_cloud_agent_exist ${agent_pool}; then

      BODY=$( jq -c -n \
        --arg type "agent-pools" \
        --arg name "${agent_pool}" \
        '
          {
            "data": {
              "type": $type,
              "attributes":
              {
                "name": $name
              }
            }
          }
        ' ) && debug " - body: $BODY"


      information "Trigger agent-pool creation."

      body=$(make_curl_request -url "$url" -options "--request POST --data '${BODY}'")

      export TF_CLOUD_AGENT_POOL_ID=$(echo ${body} | jq -r .data.id) && success "Agent pool \"${agent_pool}\" created: ${TF_CLOUD_AGENT_POOL_ID}"

    else
      url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/agent-pools" | jq -r ".data[] | select (.attributes.name==\"${1}\")"
      body=$(make_curl_request -url "$url")

      export TF_CLOUD_AGENT_POOL_ID=$(echo ${body} | jq -r .id)

      success "Agent pool \"${1}_${TF_VAR_level}\" is already created."
    fi

    create_agent_token ${TF_CLOUD_AGENT_POOL_ID} ${agent_pool} "Cloud Adoption Framework - Rover"
}

create_agent_token() {
  debug "@call create_agent_token"

# ${1} agent pool id
# ${2} agent pool name
# ${3} description

  BODY=$( jq -c -n \
  --arg type "authentication-tokens" \
  --arg description "${3}" \
  '
    {
      "data": {
        "type": $type,
        "attributes":
        {
          "description": $description
        }
      }
    }
  ' ) && debug " - body: $BODY"

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/agent-pools/${1}/authentication-tokens"
  body=$(make_curl_request -url "$url" -options "--request POST --data '${BODY}'")

  export tfc_agent_pool_token=$(echo $body | jq -r .data.attributes.token)
  register_gitops_secret ${gitops_pipelines} "${TF_VAR_level}_TF_CLOUD_AGENT_POOL_AUTH_TOKEN" ${tfc_agent_pool_token}

}

tfcloud_trigger() {
  echo "@calling tfcloud_trigger with ${1}"

  # Do a run
  sleep_duration=20
  override="no"

  rund_id="null"
  case "${tf_action}" in
      "plan")
          echo "trigger an API call for plan '${tf_command}'"
          plan_command=$(purge_command plan ${tf_command})
          echo "running terraform plan with '${plan_command}'"
          tfcloud_trigger_run_init
          tfcloud_trigger_plan "${plan_command}"
          tfcloud_monitor_run
          ;;
      "apply")
          echo "trigger an API call for apply"
          tfcloud_get_current_runid
          tfcloud_trigger_apply
          tfcloud_monitor_run
          ;;
      "destroy")
          echo "calling tfcloud destroy."
          tfcloud_trigger_plan "destroy"
          tfcloud_monitor_run
          if [[ "$check_result" == "applied" ]]; then
            tfcloud_trigger_apply
            tfcloud_monitor_run
          fi
          ;;
      *)
          error "Option ${1} not supported yet for API flow. You can submit a PR."
          ;;
  esac
}

tfcloud_get_current_runid() {
  information "@tfcloud_get_current_runid"

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/${workspace_id}/runs"
  body=$(make_curl_request -url "$url")

  runs=$(echo $body)
  debug $runs | jq -r

  run=$(echo $runs | jq -r '
    .data[] |
    select(.attributes.actions."is-confirmable" == true) |
    {
      id,
      "is-discardable": (.attributes.actions."is-discardable" // null),
      "has-changes": (.attributes."has-changes" // null)
    } |
    limit(1;.)'
  )
  run_id=$(echo $run | jq -r .id)
  is_discardable=$(echo $run | jq -r '.["is-discardable"] // null')
  has_changes=$(echo $run | jq -r '.["has-changes"] // null')

  information "run_id: ${run_id}"

}

tfcloud_trigger_plan() {
  information "@calling tfcloud_trigger_plan" >&2

  if [[ "$1" =~ (destroy|-destroy)$ ]]; then
    is_destroy=true
  else
    is_destroy=false
  fi

  BODY=$( jq -c -n \
  --arg type "runs" \
  --arg workspace_id "${workspace_id}" \
  --arg destroy $is_destroy \
  '
    {
      "data": {
        "attributes": {
          "is-destroy": $destroy
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
  ' ) && debug " - body: $BODY"

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs"
  run_result=$(make_curl_request -url "$url" -options "--request POST --data '${BODY}'")

  # Parse run_result
  run_id=$(echo $run_result | jq -r '.data.id') && echo "Run ID: " $run_id
  run_status=$(echo $run_result | jq -r '.data.attributes.status') && echo "Run status: " $run_status

  if [[ "$tf_cloud_force_run" == "true" && "$run_status" == "pending" ]]; then
    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}/actions/force-execute"
    run_result=$(make_curl_request -url "$url" -options "--request POST")
    information "Forced the run to execute."
  fi

  echo ""

}

tfcloud_trigger_apply() {
  if [[ -z ${run_id} ]]; then
    error ${LINENO} "There is no run to apply (with the action 'is-confirmable'). You will have to re-execute a plan first."
  else
    BODY=$( jq -c -n \
    --arg type "runs" \
    --arg workspace_id "${workspace_id}" \
    '
      {
        "comment": "apply by API with CAF Rover."
      }
    ' ) && debug " - body: $BODY"

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}/actions/apply"
    response=$(make_curl_request -url "$url" -options "--request POST --data '${BODY}'")

    echo $response
  fi
}

tfcloud_monitor_run() {
  # Check run result in loop
  echo ""
  echo "Checking run status"
  continue=1
  while [ $continue -ne 0 ]; do
    # Sleep
    sleep $sleep_duration

    # Check the status of run
    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}"
    response=$(make_curl_request -url "$url")

    # Parse out the run status and is-confirmable
    run_status=$(echo $response | jq -r '.data.attributes.status')
    is_confirmable=$(echo $response | jq -r '.data.attributes.actions."is-confirmable"')
    information "Run Status: $run_status - can be applied: $is_confirmable"

    # Save plan log in some cases
    save_plan="false"

    # Apply in some cases
    applied="false"

    # Run is planning - get the plan
    # sentinel_policy_set_count="** Not implemented yet **"

    # planned means plan finished and no Sentinel policy sets
    # exist or are applicable to the workspace
    if [[ "$run_status" == "planned" ]] && [[ "$is_confirmable" == "true" ]] && [[ "$override" == "no" ]]; then
      continue=0
      echo ""
      echo "There are ${sentinel_policy_set_count} policy sets, but none of them are applicable to this workspace."
      echo "Check the run in Terraform Enterprise UI and apply there if desired."
      save_plan="true"
    # cost_estimated means plan finished and costs were estimated
    # exist or are applicable to the workspace
    elif [[ "$run_status" == "cost_estimated" ]] && [[ "$is_confirmable" == "true" ]] && [[ "$override" == "no" ]]; then
      continue=0
      echo ""
      echo "There are ${sentinel_policy_set_count} policy sets, but none of them are applicable to this workspace."
      echo "Check the run in Terraform Enterprise UI and apply there if desired."
      save_plan="true"
    elif [[ "$run_status" == "planned" ]] && [[ "$is_confirmable" == "true" ]] && [[ "$override" == "yes" ]]; then
      continue=0
      echo ""
      echo "There are ${sentinel_policy_set_count} policy sets, but none of them are applicable to this workspace."
      echo "Since override was set to \"yes\", we are applying."
      # Do the apply
      echo "Doing Apply"
      apply_result=tfcloud_apply
      applied="true"
    elif [[ "$run_status" == "cost_estimated" ]] && [[ "$is_confirmable" == "true" ]] && [[ "$override" == "yes" ]]; then
      continue=0
      echo ""
      echo "There are ${sentinel_policy_set_count} policy sets, but none of them are applicable to this workspace."
      echo "Since override was set to \"yes\", we are applying."
      # Do the apply
      echo "Doing Apply"
      apply_result=tfcloud_apply
      applied="true"
    # policy_checked means all Sentinel policies passed
    elif [[ "$run_status" == "policy_checked" ]]; then
      continue=0
      # Do the apply
      echo ""
      echo "Policies passed. Doing Apply"
      apply_result=tfcloud_apply
      applied="true"
    # policy_override means at least 1 Sentinel policy failed
    # but since $override is "yes", we will override and then apply
    elif [[ "$run_status" == "policy_override" ]] && [[ "$override" == "yes" ]]; then
      continue=0
      echo ""
      echo "Some policies failed, but overriding"
      # Get the policy check ID
      echo ""
      echo "Getting policy check ID"
      url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}/policy-checks" && policy_result=$(make_curl_request -url "$url")
      # Parse out the policy check ID
      policy_check_id=$(echo $policy_result | jq -r '.data[0].id')
      echo ""
      echo "Policy Check ID: " $policy_check_id
      # Override policy
      echo ""
      echo "Overriding policy check"
      url="https://${TF_VAR_tf_cloud_hostname}/api/v2/policy-checks/${policy_check_id}/actions/override" && override_result=$(make_curl_request -url "$url" -options "--request POST")
      # Do the apply
      echo ""
      echo "Doing Apply"
      apply_result=tfcloud_apply
      applied="true"
    # policy_override means at least 1 Sentinel policy failed
    # but since $override is "no", we will not override
    # and will not apply
    elif [[ "$run_status" == "policy_override" ]] && [[ "$override" == "no" ]]; then
      echo ""
      echo "Some policies failed, but will not override. Check run in Terraform Enterprise UI."
      save_plan="true"
      continue=0
    # errored means that plan had an error or that a hard-mandatory
    # policy failed
    elif [[ "$run_status" == "errored" ]]; then
      echo ""
      echo "Plan errored or hard-mandatory policy failed"
      save_plan="true"
      continue=0
    elif [[ "$run_status" == "planned_and_finished" ]]; then
      echo ""
      echo "Plan indicates no changes to apply."
      save_plan="true"
      continue=0
    elif [[ "$run_status" == "canceled" ]]; then
      echo ""
      echo "The run was canceled."
      continue=0
    elif [[ "$run_status" == "force_canceled" ]]; then
      echo ""
      echo "The run was canceled forcefully."
      continue=0
    elif [[ "$run_status" == "discarded" ]]; then
      echo ""
      echo "The run was discarded."
      continue=0
    elif [[ "$run_status" == "applied" ]]; then
      echo ""
      echo "The run has been applied."
      applied="true"
      continue=0
    else
      # Sleep and then check status again in next loop
      debug "We will sleep and try again soon."
    fi
  done

  # Get the plan log if $save_plan is true
  #
  # TODO: Display only plan. Do we need to save it as a job artifact?
  #
  if [[ "$save_plan" == "true" && ("${tf_action}" == "plan" || "${tf_action}" == "destroy") ]]; then
    echo ""
    echo "Getting the result of the Terraform Plan."

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}/plan"
    run_result=$(make_curl_request -url "$url")
    debug $(echo $run_result | jq)
    has_changes=$(echo $run_result | jq -r '.data.attributes."has-changes"')
    log_url_plan=$(echo $run_result | jq -r '.data.attributes."log-read-url"')
    curl -sS $log_url_plan
    echo ""
    warning "Terraform has changes: $has_changes"
  fi

  # Get the apply log and state file if an apply was done
  if [[ "${tf_action}" == "apply" ]]; then

    echo ""
    echo "An apply was done."
    echo "Will download apply log and state file."

    # Get run details including apply information
    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}?include=apply" && check_result=$(make_curl_request -url "$url")

    # Get apply ID
    apply_id=$(echo $check_result | jq -r '.included[0].id')
    echo ""
    echo "Apply ID:" $apply_id

    # Check apply status periodically in loop
    continue=1
    while [ $continue -ne 0 ]; do

      sleep $sleep_duration
      echo ""
      echo "Checking apply status"

      # Check the apply status
      url="https://${TF_VAR_tf_cloud_hostname}/api/v2/applies/${apply_id}" && check_result=$(make_curl_request -url "$url")

      # Parse out the apply status
      apply_status=$(echo $check_result | jq -r '.data.attributes.status')
      echo "Apply Status: ${apply_status}"

      # Decide whether to continue
      if [[ "$apply_status" == "finished" ]]; then
        echo "Apply finished."
        continue=0
      elif [[ "$apply_status" == "errored" ]]; then
        echo "Apply errored."
        continue=0
      elif [[ "$apply_status" == "canceled" ]]; then
        echo "Apply was canceled."
        continue=0
      else
        # Sleep and then check apply status again in next loop
        echo "We will sleep and try again soon."
      fi
    done

    # Get apply log urldebug $(echo $run_result | jq)
    has_changes=$(echo $check_result | jq -r '.data.attributes."has-changes"')
    apply_log_url=$(echo $check_result | jq -r '.data.attributes."log-read-url"')
    echo ""
    debug "Apply Log url: ${apply_log_url}"

    # Retrieve Apply Log from the url
    # and output to shell and file
    echo "Downloading the logs..."
    curl -sS -o ${TF_DATA_DIR}/${apply_id}.log $apply_log_url && cat ${TF_DATA_DIR}/${apply_id}.log
    echo ""

    if [[ "${apply_status}" == "errored" ]]; then
      error "Apply failed"
    fi
  fi
}

function make_curl_request() {

  local url=""
  local gracefully_continue=false
  local options=""

  # parse command line arguments
  while [[ $# -gt 0 ]]
  do
    key="$1"

    case $key in
      -url)
        url="$2"
        shift 2
        ;;
      -gracefully_continue)
        gracefully_continue=true
        shift
        ;;
      -options)
        options="$2"
        shift 2
        ;;
      -data)
        options+=" --data '"${2}"'"
        shift 2
        ;;
      *)
        error "$key option not supported."
        ;;
    esac
  done

  command="curl -sS -L -w '%{http_code}' --header 'Authorization: Bearer xxxxxx' --header 'Content-Type: application/vnd.api+json' $options -- '"${url}"' 2> >(tee -a >&2)"
  debug "$(echo "Running command: $command")" >&2
  command="curl -sS -L -w '%{http_code}' --header 'Authorization: Bearer  "$REMOTE_ORG_TOKEN"' --header 'Content-Type: application/vnd.api+json' $options -- '"${url}"' 2> >(tee -a >&2)"

  response=$(eval $command)
  return_code=$?

  debug $response >&2
  http_code="$(echo $response | tail -c 4)"
  body=$(echo $response | head -c -4)
  process_curl_response -status "$return_code" -http_code "$http_code" -url "$url" -gracefully_continue $gracefully_continue

  # Send the return value
  echo $body
}


function process_curl_response() {

  local url=""
  local status=""
  local http_code=""
  local gracefully_continue=false
  local options=""

  # parse command line arguments
  while [[ $# -gt 0 ]]
  do
    key="$1"

    case $key in
      -url)
        url="$2"
        shift 2
        ;;
      -status)
        status="$2"
        shift 2
        ;;
      -http_code)
        http_code="$2"
        shift 2
        ;;
      -gracefully_continue)
        gracefully_continue=$2
        shift 2
        ;;
      *)
        error "$key option not supported."
        ;;
    esac
  done

  # status=$1
  # http_code=$2
  # url=$3
  # gracefully_continue=$4

  if [ $status -ne 0 ]; then
    error "Error: curl exited with status $status" >&2
    exit 1
  elif ! [[ ${http_code} =~ ^(200|201|202|203|204|307)$ ]]; then
    if [[ ${gracefully_continue} && "${http_code}" =~ ^4[0-9]{2}$ ]]; then
      information "Gracefully continue on error: HTTP status code is ${http_code} for ${url}" >&2
    else
      error ${LINENO} "Error: HTTP status code is ${http_code} for ${url}" >&2
      exit 1
    fi
  else
    debug "Success: HTTP status code is ${http_code}" >&2
  fi
}
