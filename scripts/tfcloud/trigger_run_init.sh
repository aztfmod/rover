
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
  cd ${TF_var_folder}
  tar -cvf ${CONFIG_PATH}/configuration.tar --recursive --exclude "**/*.tfvars" --exclude "**/*.md" . 1>/dev/null

  cd ${landingzone_name}
  UPLOAD_FILE_NAME="${CONFIG_PATH}/caf-landingzones-$(date +%s).tar"
  tar -cvf "${UPLOAD_FILE_NAME}" \
    --exclude "**/_pictures" \
    --exclude "**/examples" \
    --exclude "**/.*" \
    --exclude "**/terraform.tfstate" \
    --exclude "**/terraform.tfstate.backup" \
    --exclude "**/documentation" \
    --exclude "**/scenario" \
    --exclude "**/*.md" \
    --exclude "**/*.log" \
    --exclude "**/add-ons"\
    . 1>/dev/null

  # concatenate
  tar -A --file=${UPLOAD_FILE_NAME} ${CONFIG_PATH}/configuration.tar
  gzip -k ${UPLOAD_FILE_NAME}
  tar -tzf "${UPLOAD_FILE_NAME}.gz"
  UPLOAD_FILE_NAME="${UPLOAD_FILE_NAME}.gz"

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
  # Structure:
  # key,varname,description,sensitive,allowempty,var_category
  vars_rover=("ARM_CLIENT_ID,ARM_CLIENT_ID,Service Principal client_id,false,false,env",
    "ARM_TENANT_ID,ARM_TENANT_ID,Tenant ID,false,false,env",
    "TF_VAR_rover_version,TF_VAR_rover_version,Version of the CAF Rover docker image,false,false,env",
    "ARM_STORAGE_USE_AZUREAD,ARM_STORAGE_USE_AZUREAD,Should the AzureRM Provider use AzureAD to connect to the Storage Blob & Queue API rather than the SharedKey from the Storage Account?,false,false,env",
    "TF_VAR_user_type,TF_VAR_user_type,Principal type (user or service principal),false,false,env",
    "TF_VAR_tfstate_organization,TF_VAR_tfstate_organization,Organization name,false,false,env",
    "TF_VAR_tfstate_hostname,TF_VAR_tfstate_hostname,URL of the endpoint,false,false,env",
    "TF_VAR_environment,TF_VAR_environment,CAF environment,false,false,env",
    "TF_VAR_tenant_id,ARM_TENANT_ID,Tenant ID,false,false,env",
    "lower_storage_account_name,lower_storage_account_name,AzureRM lower storage account name,false,false,terraform",
    "lower_container_name,lower_container_name,AzureRM lower storage account container name,false,false,terraform",
    "lower_resource_group_name,lower_resource_group_name,AzureRM lower resource group name,false,false,terraform",
    "tfstate_storage_account_name,tfstate_storage_account_name,AzureRM current storage account name,false,false,terraform",
    "tfstate_container_name,tfstate_container_name,AzureRM current storage container name,false,false,terraform",
    "tfstate_resource_group_name,tfstate_resource_group_name,AzureRM current resource group name,false,false,terraform",
    "ARM_SUBSCRIPTION_ID,ARM_SUBSCRIPTION_ID,Target subscription id to deploy the resources,false,false,env",
    "ARM_CLIENT_SECRET,ARM_CLIENT_SECRET,Client secret of the service principal.,true,false,env")

  tf_vars_prefixes=("TF_CLOUD_WORKSPACE_TF_SEC_VAR_,,,true,false,terraform",
    "TF_CLOUD_WORKSPACE_TF_VAR_,,,false,false,terraform",
    "TF_CLOUD_WORKSPACE_TF_SEC_ENV_,,,true,false,env",
    "TF_CLOUD_WORKSPACE_TF_ENV_,,,false,false,env"
  )

  # Store all the variables added to the workspace
  vars_workspace=()

  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${TF_VAR_tf_cloud_organization}&filter%5Bworkspace%5D%5Bname%5D=${TF_VAR_workspace}"
  debug $url
  vars=$(make_curl_request -url "$url")
  debug $vars

  for var_obj_rover in "${vars_rover[@]}"; do
    workspace_process_variable_rover "$var_obj_rover"
  done

  # Process tf_vars_prefixes
  for var_obj_prefix in "${tf_vars_prefixes[@]}"; do
    workspace_process_variable_prefixes $var_obj_prefix
  done

  # Remove variables not set by the rover
  workspace_variable_delete

  # 6. Grant workspace permissions
  #
  # Each tfstates defined in the var.landingzone.tfstates or var.landingzone.remote_tfstates
  #
  conf_lz=$(grep -rl "^landingzone = {" ${TF_var_folder}/*.tfvars || true)
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
  url="https://${TF_VAR_tf_cloud_hostname}/api/v2/organizations/${TF_VAR_tf_cloud_organization}/policy-sets"
  sentinel_list_result=$(make_curl_request -url "$url")
  sentinel_policy_set_count=$(echo $sentinel_list_result | tr '\r\n' ' ' | jq -r '.meta.pagination."total-count"')
  echo ""
  echo "Number of Sentinel policy sets: " $sentinel_policy_set_count
  run_id="null"
}
