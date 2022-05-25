
get_logged_in_user_object_id() {
  debug "@calling get_logged_in_user_object_id"

  # Return objectId of the current Azure session
  az ad signed-in-user show --query objectId -o tsv --only-show-errors

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
      information "Failed to create the app and sp. retrying"
      sleep 5
      create_federated_identity ${appName}
    fi

    app_object_id=$(echo ${app} | jq -r ".objectId")
    client_id=$(echo ${sp} | jq -r ".appId")
    object_id=$(echo ${sp} | jq -r ".objectId")

    register_gitops_secret ${gitops_pipelines} "AZURE_CLIENT_ID" ${client_id}
    register_gitops_secret ${gitops_pipelines} "AZURE_OBJECT_ID" ${object_id}
    register_gitops_secret ${gitops_pipelines} "AZURE_TENANT_ID" ${tenant_id}
  
  else
    success " - application already created."
    success " - service principal already created."
  fi


  app=$(az ad app list --filter "displayname eq '${appName}'" -o json --only-show-errors)
  sp=$(az ad sp list --filter "DisplayName eq '${appName}'" --only-show-errors)
  export app_object_id=$(echo ${app} | jq -r ".[0].objectId")
  create_gitops_federated_credentials ${gitops_pipelines} ${appName}

  az role assignment create \
    --role "Owner" \
    --assignee-object-id $(echo ${sp} | jq -r ".[0].objectId") \
    --assignee-principal-type ServicePrincipal \
    --scope /subscriptions/${TF_VAR_tfstate_subscription_id} \
    --only-show-errors

}


function create_federated_credentials {

  cred=$(az rest --uri "https://graph.microsoft.com/beta/applications/${app_object_id}/federatedIdentityCredentials" --query "value[?name=='${1}'].{name:name}[0]" -o tsv)

  if [ -z "${cred}" ]; then
    echo "Adding federated credential to ${app_object_id} with 'name':'${1}','subject':'${2}','description':'${3}'"

    az rest --method POST \
      --uri "https://graph.microsoft.com/beta/applications/${app_object_id}/federatedIdentityCredentials" \
      --body "{'name':'${1}','issuer':'https://token.actions.githubusercontent.com','subject':'${2}','description':'${3}','audiences':['api://AzureADTokenExchange']}"
  fi

}