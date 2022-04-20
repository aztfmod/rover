#!/bin/bash

# Complete script for API-driven runs.
# Documentation can be found at:
# https://www.terraform.io/docs/cloud/run/api.html

# 1. Define Variables

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <path_to_content_directory> <organization>/<workspace>"
  exit 1
fi

CONTENT_DIRECTORY="$1"
ORG_NAME="$(cut -d'/' -f1 <<<"$2")"
WORKSPACE_NAME="$(cut -d'/' -f2 <<<"$2")"
CONFIG_PATH="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

# 2. Create the File for Upload

UPLOAD_FILE_NAME="${CONFIG_PATH}/content-$(date +%s).tar.gz"
tar -zcvf "$UPLOAD_FILE_NAME" -C "$CONTENT_DIRECTORY" .

# 3. Look Up the Workspace ID

WORKSPACE_ID=($(curl \
  --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://${REMOTE_hostname}/api/v2/organizations/$ORG_NAME/workspaces/$WORKSPACE_NAME \
  | jq -r '.data.id'))

# 4. Create a New Configuration Version

echo '{"data":{"type":"configuration-versions"}}' > ${CONFIG_PATH}/create_config_version.json

UPLOAD_URL=($(curl \
  --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @\"${CONFIG_PATH}/create_config_version.json\" \
  https://${REMOTE_hostname}/api/v2/workspaces/$WORKSPACE_ID/configuration-versions \
  | jq -r '.data.attributes."upload-url"'))

# 5. Upload the Configuration Content File

curl \
  --header "Content-Type: application/octet-stream" \
  --request PUT \
  --data-binary @"$UPLOAD_FILE_NAME" \
  $UPLOAD_URL

# 6. Delete Temporary Files

rm "$UPLOAD_FILE_NAME"
rm ${CONFIG_PATH}/create_config_version.json
