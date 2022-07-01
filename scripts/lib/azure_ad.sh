
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
    sp_object_id=$(echo ${sp} | jq -r ".id")

    if [ ! -z  ${gitops_pipelines} ]; then
      register_gitops_secret ${gitops_pipelines} "AZURE_CLIENT_ID" ${sp_client_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_OBJECT_ID" ${app_object_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_TENANT_ID" ${tenant_id}
    fi
  
  else
    success " - application already created."
    success " - service principal already created."

    app=$(az ad app list --filter "displayname eq '${appName}'" -o json --only-show-errors) && debug "app: ${app}"
    sp=$(az ad sp list --filter "DisplayName eq '${appName}'" --only-show-errors) && debug "sp: ${sp}"
    export app_object_id=$(echo ${app} | jq -r ".[0].id")
    sp_client_id=$(echo ${app} | jq -r ".[0].appId")
    sp_object_id=$(echo ${sp} | jq -r ".[0].id")


    if [ ! -z  ${gitops_pipelines} ]; then
      register_gitops_secret ${gitops_pipelines} "AZURE_CLIENT_ID" ${sp_client_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_OBJECT_ID" ${app_object_id}
      register_gitops_secret ${gitops_pipelines} "AZURE_TENANT_ID" ${tenant_id}
    fi

    fi

  if [ ! -z  ${gitops_pipelines} ]; then
    create_gitops_federated_credentials ${gitops_pipelines} ${appName}

    scope="/subscriptions/${sub_management:=$(az account show --query id -o tsv)}"
    information "Granting Reader role to ${appName} on ${scope}"
    az role assignment create \
      --role "Reader" \
      --assignee-object-id ${sp_object_id} \
      --assignee-principal-type ServicePrincipal \
      --scope ${scope} \
      --only-show-errors
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