# setup an initial launchpad for remote state management

init() {
  rg_name="${TF_VAR_environment}-launchpad"
  location=${location:=australiaeast}

  current_rg=$(az group list --query "[?tags.caf_environment=='${TF_VAR_environment}'] && [?tags.caf_tfstate=='${TF_VAR_level}']")

  if [ "${tf_command}" == "--clean" ]; then
    if [ "${current_rg}" != "[]" ]; then
      resource_group_delete ${rg_name} ${location}
    else
      echo "Launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in /subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${rg_name} has been clean-up."
    fi
  else
    if [ "${current_rg}" == "[]" ];then
      resource_group ${rg_name} ${location}
      storage_account ${rg_name} ${location}
      keyvault ${rg_name} ${location}
      display_instructions
    else
      echo "Launchpad already deployed in ${current_rg}"
    fi
  fi
}

resource_group_delete() {
  rg_name=${1}
  location=${2}

  echo "Deleting launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in /subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${rg_name}"
  az group delete \
    --name ${rg_name} \
    --no-wait \
    --yes

  az group wait --deleted  --resource-group ${rg_name}

  echo "Launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in ${rg_name} destroyed."
}

resource_group() {
  rg_name=${1}
  location=${2}

  echo "Creating resource group: ${rg_name}"
    az group create \
    --name ${rg_name} \
    --location ${location} \
    --tags caf_environment=${TF_VAR_environment} caf_tfstate=${TF_VAR_level} \
    --subscription ${TF_VAR_tfstate_subscription_id} \
    --only-show-errors \
    --query id \
    -o tsv

  az group wait --created  --resource-group ${rg_name}
  echo "  ...created"
}

storage_account() {
  rg_name=${1}
  location=${2}

  random_length=$((22 - ${#TF_VAR_environment}))
  typeset -l name
  name="st${TF_VAR_environment}$(echo $RANDOM | md5sum | head -c ${random_length}; echo;)"

  if [ "$(az storage account list --resource-group ${rg_name})" == "[]" ]; then

    if [ "$(az storage account check-name --name ${name} --query nameAvailable -o tsv)" == "true" ]; then
      echo "Creating storage account: ${name}"
      id=$(az storage account create \
        --name ${name} \
        --resource-group ${rg_name} \
        --location ${location} \
        --allow-blob-public-access false \
        --sku Standard_LRS \
        --tags caf_environment=${TF_VAR_environment} caf_tfstate=${TF_VAR_level} \
        --query id \
        -o tsv) && echo $id

      echo "stg created"
      az role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee $(az ad signed-in-user show --query userPrincipalName -o tsv) \
        --scope $id \
        --query id

      echo "role"
      az storage container create \
        --name ${TF_VAR_workspace} \
        --account-name ${name} \
        --auth-mode login \
        --public-access off \
        --query created

    else
      echo "Storage account name already exists"
      exit 1
    fi
  fi

}

keyvault() {
  rg_name=${1}
  location=${2}

  random_length=$((22 - ${#TF_VAR_environment}))
  typeset -l name
  name="kv${TF_VAR_environment}$(echo $RANDOM | md5sum | head -c ${random_length}; echo;)"

  if [ "$(az keyvault list --resource-group ${rg_name})" == "[]" ]; then

    echo "Creating keyvault: ${name}"
    az keyvault create \
      --name ${name} \
      --resource-group ${rg_name} \
      --location ${location} \
      --tags caf_environment=${TF_VAR_environment} caf_tfstate=${TF_VAR_level} \
      --query id

    az keyvault secret set \
      --name "subscription-id" \
      --vault-name ${name} \
      --value ${TF_VAR_tfstate_subscription_id} \
      --query id

    az keyvault secret set \
      --name "tenant-id" \
      --vault-name ${name} \
      --value $(az account show --query tenantId -o tsv) \
      --query id

    echo "  ...created"
  fi

}