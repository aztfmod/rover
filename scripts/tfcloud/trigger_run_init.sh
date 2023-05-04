#!/bin/bash

tfcloud_trigger_run_init(){
  # Complete script for API-driven runs.
  # Documentation can be found at:
  # https://www.terraform.io/docs/cloud/run/api.html


  information "@calling terraform api trigger for action ${tf_action}"

  # 1. Define Variables

  ORG_NAME=${TF_VAR_tf_cloud_organization}
  WORKSPACE_NAME=${TF_VAR_workspace}
  CONFIG_PATH="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

  # 2. Create the File for Upload

  UPLOAD_FILE_NAME="${CONFIG_PATH}/caf-landingzones-$(date +%s).tar.gz"
  tar -zcvf "$UPLOAD_FILE_NAME" \
    --exclude "**/_pictures" \
    --exclude "**/examples" \
    --exclude "**/.*" \
    --exclude "**/terraform.tfstate" \
    --exclude "**/terraform.tfstate.backup" \
    --exclude "**/documentation" \
    --exclude "**/scenario" \
    --exclude "**/*.md" \
    --exclude "**/*.log" \
    . ./.terraform.lock.hcl
    # 1>/dev/null

  # 3. Look Up the Workspace ID
  get_remote_token

  echo "workspace_id is: $workspace_id"

  # 4. Create a New Configuration Version

  # Create configuration version
  echo ""
  echo "Creating configuration version."

  # echo '{"data":{"type":"configuration-versions","attributes": {"auto-queue-runs":false}}}' > ${CONFIG_PATH}/create_config_version.json

    BODY=$( jq -c -n \
      --arg type "configuration-versions" \
      --arg description "${3}" \
      '
        {
          "data": {
            "type": $type,
            "attributes":
            {
              "auto-queue-runs": false
            }
          }
        }
      ' ) && debug " - body: $BODY"

  # configuration_version_result=$(curl -s \
  #   --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
  #   --header "Content-Type: application/vnd.api+json" \
  #   --request POST \
  #   --data @${CONFIG_PATH}/create_config_version.json \
  #   https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/$workspace_id/configuration-versions)

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/workspaces/$workspace_id/configuration-versions"
  configuration_version_result=$(make_curl_request -url "$url" -options "--request POST" -data "${BODY}")

  # Parse configuration_version_id and upload_url
  config_version_id=$(echo $configuration_version_result | jq -r '.data.id')
  upload_url=$(echo $configuration_version_result | jq -r '.data.attributes."upload-url"')
  echo ""
  echo "Config Version ID: " $config_version_id

  # 5. Upload the Configuration Content File

  curl -s \
    --header "Content-Type: application/octet-stream" \
    --request PUT \
    --data-binary @${UPLOAD_FILE_NAME} \
    $upload_url

  rm "$UPLOAD_FILE_NAME"

  # Inject variables

  # Rover variables

  vars_rover=("ARM_CLIENT_ID,ARM_CLIENT_ID,Service Principal client_id,false,false",
    "ARM_TENANT_ID,ARM_TENANT_ID,Tenant ID,false,false",
    "TF_VAR_rover_version,TF_VAR_rover_version,Version of the CAF Rover docker image,false,false",
    "ARM_STORAGE_USE_AZUREAD,ARM_STORAGE_USE_AZUREAD,Should the AzureRM Provider use AzureAD to connect to the Storage Blob & Queue API rather than the SharedKey from the Storage Account?,false,false",
    "TF_VAR_user_type,TF_VAR_user_type,Principal type (user or service principal),false,false",
    "TF_VAR_tfstate_organization,TF_VAR_tfstate_organization,Organization name,false,false",
    "TF_VAR_tfstate_hostname,TF_VAR_tfstate_hostname,URL of the endpoint,false,false",
    "TF_VAR_environment,TF_VAR_environment,CAF environment,false,false",
    "TF_VAR_tenant_id,ARM_TENANT_ID,Tenant ID,false,false",
    "ARM_SUBSCRIPTION_ID,ARM_SUBSCRIPTION_ID,Target subscripiton id to deploy the resources,false,false",
    "ARM_CLIENT_SECRET,ARM_CLIENT_SECRET,Client secret of the service principal.,true,false")

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${TF_VAR_tf_cloud_organization}&filter%5Bworkspace%5D%5Bname%5D=${TF_VAR_workspace}"
    debug $url
    vars=$(make_curl_request -url "$url")
    debug $vars

  for var_obj in "${vars_rover[@]}"
  do
    IFS=',' read -r key varname description sensitive allowempty <<< "$var_obj"
    value=$(env | grep $varname | cut -d= -f2)

    var_id=$(echo $vars | jq -r ".data[] | select(.attributes.key == \"$key\") | .id")

    if [[ "$allowempty" == "false" && -z "$value" ]];then
      error "$var environment variable has not been set."
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
            '
              {
                "data": {
                  "attributes": {
                    "key": $key,
                    "value": $value,
                    "description": $description,
                    "category": "env",
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
            '
              {
                "data": {
                  "id": $id,
                  "attributes": {
                    "key": $key,
                    "value": $value,
                    "description": $description,
                    "category": "env",
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

  done

  # 6. Grant workspace permissions
  #
  # Each tfstates defined in the var.landingzone.tfstates or var.landingzone.remote_tfstates
  #
  conf_lz=$(grep -rl "landingzone = {" ${TF_var_folder}/*.tfvars)
  if [ ! -z "$conf_lz" ]; then
    conf_lz_json=$(python3 ${script_path}/tfcloud/hcl_parser.py -input ${conf_lz} -env ${TF_VAR_environment})
    warning $conf_lz_json
    keys=($(echo $conf_lz_json | jq -r '.landingzone.tfstates | keys[]'))
    for key in "${keys[@]}"; do
      tfcloud_workspace_name=$(echo "$conf_lz_json" | jq -r --arg key "$key" '.landingzone.tfstates[$key].tfcloud_workspace_name')
      echo "${WORKSPACE_NAME} - Processing key: $key, tfcloud_workspace_name: $tfcloud_workspace_name"

      # Verify the remote state has been granted permission
      remote_workspace_id=$(workspace_get ${tfcloud_workspace_name})
      if [[ "$remote_workspace_id" == "null" ]]; then
        warning "The remote workspace does not exist or has not been yet migrated to terraform tfcloud remote backend."
        warning "skipping..."
      else
        information "Granting the permission for ${tfcloud_workspace_name} to access the workspace ${WORKSPACE_NAME}"
        isset=$(workspace_remote_state_consumers_is_set "${remote_workspace_id}" "${workspace_id}")
        if [[ "$isset" == "null" ]]; then
          workspace_remote_state_consumers_add "${remote_workspace_id}" "${workspace_id}"
        fi
      fi
    done
  fi

  # List Sentinel Policy Sets
  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/policy-sets" && sentinel_list_result=$(make_curl_request -url "$url")
  sentinel_policy_set_count=$(echo $sentinel_list_result | tr '\r\n' ' ' | jq -r '.meta.pagination."total-count"')
  echo ""
  echo "Number of Sentinel policy sets: " $sentinel_policy_set_count
  run_id="null"
}