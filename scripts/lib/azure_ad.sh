microsoft_graph_endpoint=$(az cloud show | jq -r ".endpoints.microsoftGraphResourceId")

get_logged_in_user_object_id() {
  debug "@calling get_logged_in_user_object_id"

  # Return objectId of the current Azure session
  az ad signed-in-user show --query id -o tsv --only-show-errors

}


#
# Create a federated identity to deploy the launchpad
#
create_federated_identity() {
  debug "@calling create_federated_identity"

  information "Verifying Azure AD Application and Service Principal for '${1}'"

  export appName=${1}
  app=$(az ad app list --filter "displayname eq '${appName}'" -o json --only-show-errors)

  if [ "${app}" = "[]" ]; then
    information "Application ${1}:"
    az rest --method post --url "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"

    # Create Azure AD application
    app=$(az ad app create --display-name "${appName}" --only-show-errors)
    success " - application created."

    # Create service principal
    sp=$(az ad sp create --id $(echo $app | jq -r .appId) --only-show-errors)
    success " - service principal created."

    if [ "${sp}" = '' ]; then
      information "Failed to create the app and sp. Check your permissions."
      exit 1
    fi

    export app_object_id=$(echo ${app} | jq -r ".id")
    sp_client_id=$(echo ${sp} | jq -r ".appId")
    export sp_object_id=$(echo ${sp} | jq -r ".id")

    if [ ! -z  ${gitops_pipelines} ]; then
      register_gitops_secret ${gitops_pipelines} "AZURE_CLIENT_ID" ${sp_client_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_OBJECT_ID" ${app_object_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_TENANT_ID" ${tenant_id}
    fi

    manage_sp_to_role "Privileged Role Administrator" ${sp_object_id} "POST"
    manage_sp_to_role "Application Administrator" ${sp_object_id} "POST"
    manage_sp_to_role "Groups Administrator" ${sp_object_id} "POST"
  
  else
    success " - application already created."
    success " - service principal already created."

    app=$(az ad app list --filter "displayname eq '${appName}'" -o json --only-show-errors) && debug "app: ${app}"
    sp=$(az ad sp list --filter "DisplayName eq '${appName}'" --only-show-errors) && debug "sp: ${sp}"
    export app_object_id=$(echo ${app} | jq -r ".[0].id") && information "app_object_id: ${app_object_id}"
    export sp_client_id=$(echo ${app} | jq -r ".[0].appId") && information "sp_client_id: ${sp_client_id}"
    export sp_object_id=$(echo ${sp} | jq -r ".[0].id") && information "sp_object_id: ${sp_object_id}"


    if [ ! -z  ${gitops_pipelines} ]; then
      register_gitops_secret ${gitops_pipelines} "AZURE_CLIENT_ID" ${sp_client_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_OBJECT_ID" ${sp_object_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_TENANT_ID" ${tenant_id}
    fi

    fi

  if [ ! -z  ${gitops_pipelines} ]; then
    create_gitops_federated_credentials ${gitops_pipelines} ${appName}
  fi
}


function create_federated_credentials {

  debug "az rest --uri \"https://graph.microsoft.com/beta/applications/${app_object_id}/federatedIdentityCredentials\" --query \"value[?name==\'${1}\'].{name:name}[0]\" -o json"

  cred=$(az rest --uri "https://graph.microsoft.com/beta/applications/${app_object_id}/federatedIdentityCredentials" --query "value[?name=='${1}'].{name:name}[0]" -o json | jq -r .name)
  debug "value is '${cred}'"

  if [ "${cred}" = '' ]; then
    information "Adding federated credential to ${app_object_id} with 'name':'${1}','subject':'${2}','description':'${3}'"

    az rest --method POST \
      --uri "https://graph.microsoft.com/beta/applications/${app_object_id}/federatedIdentityCredentials" \
      --body "{'name':'${1}','issuer':'https://token.actions.githubusercontent.com','subject':'${2}','description':'${3}','audiences':['api://AzureADTokenExchange']}"
  else
    information "Federated tokens up-to-date for '${2}'."
  fi

}



function enable_directory_role {
    # Verify the AD_ROLE_NAME has been activated in the directory
    # Permissions required - https://docs.microsoft.com/en-us/graph/api/directoryrole-post-directoryroles?view=graph-rest-1.0&tabs=http#permissions

    AD_ROLE_NAME=${1}

    information "Enabling directory role: ${AD_ROLE_NAME}"
    ROLE_ID=$(az rest --method Get --uri ${microsoft_graph_endpoint}v1.0/directoryRoleTemplates -o json | jq -r '.value[] | select(.displayName == "'"$(echo ${AD_ROLE_NAME})"'") | .id')

    URI="${microsoft_graph_endpoint}v1.0/directoryRoles"

    JSON=$( jq -n \
                --arg role_id ${ROLE_ID} \
            '{"roleTemplateId": $role_id}' ) && echo " - body: $JSON"


    az rest --method POST --uri $URI --header Content-Type=application/json --body "$JSON"

}

function manage_sp_to_role() {

  AD_ROLE_NAME=${1}
  SERVICE_PRINCIPAL_OBJECT_ID=${2}
  METHOD=${3}
  echo "Directory role '${AD_ROLE_NAME}'"


  # Add service principal to AD Role

  export ROLE_AAD=$(az rest --method Get --uri ${microsoft_graph_endpoint}v1.0/directoryRoles -o json | jq -r '.value[] | select(.displayName == "'"$(echo ${AD_ROLE_NAME})"'") | .id')

  if [ "${ROLE_AAD}" == '' ]; then
      enable_directory_role
      export ROLE_AAD=$(az rest --method Get --uri ${microsoft_graph_endpoint}v1.0/directoryRoles -o json | jq -r '.value[] | select(.displayName == "'"$(echo ${AD_ROLE_NAME})"'") | .id')
  fi

  # az rest --method Get --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$filter=principalId+eq+'e72ea7c1-82cd-4f45-8680-41052872763e'"


  case "${METHOD}" in
      POST)
          URI=$(echo  "${microsoft_graph_endpoint}v1.0/directoryRoles/${ROLE_AAD}/members/\$ref") && echo " - uri: $URI"

          # grant AAD role to the AAD APP
          JSON=$( jq -n \
              --arg uri_role "${microsoft_graph_endpoint}v1.0/directoryObjects/${SERVICE_PRINCIPAL_OBJECT_ID}" \
              '{"@odata.id": $uri_role}' ) && echo " - body: $JSON"

          az rest --method ${METHOD} --uri $URI --header Content-Type=application/json --body "$JSON"

          information "Role '${AD_ROLE_NAME}' assigned to azure ad principal"
          ;;
      DELETE)
          URI=$(echo  "${microsoft_graph_endpoint}v1.0/directoryRoles/${ROLE_AAD}/members/${SERVICE_PRINCIPAL_OBJECT_ID}/\$ref") && echo " - uri: $URI"
          az rest --method ${METHOD} --uri ${URI} || true
          information "Role '${AD_ROLE_NAME}' unassigned to azure ad principal ${SERVICE_PRINCIPAL_OBJECT_ID}"
          ;;
  esac

}
