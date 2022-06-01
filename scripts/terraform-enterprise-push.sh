#!/bin/bash

# Complete script for API-driven runs.
# Documentation can be found at:
# https://www.terraform.io/docs/cloud/run/api.html

source ${script_path}/lib/tfcloud.sh
source ${script_path}/lib/logger.sh

information "@calling terraform api trigger"
# 1. Define Variables

AZTFMOD_DIRECTORY=$(git rev-parse --show-toplevel)/aztfmod
ORG_NAME=${REMOTE_organization}
WORKSPACE_NAME=${TF_VAR_workspace}
CONFIG_PATH="${TF_DATA_DIR}/${TF_VAR_environment}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"

# 2. Create the File for Upload

cp -r ${landingzone_name} ${CONFIG_PATH}/module
cp -r ${AZTFMOD_DIRECTORY} ${CONFIG_PATH}/module/aztfmod
find ${CONFIG_PATH}/module -type f -name '*.tf' | xargs sed -i 's/\.\.\/aztfmod/\.\/aztfmod/g'

UPLOAD_FILE_NAME="${CONFIG_PATH}/caf-landingzones-$(date +%s).tar.gz"
tar -zcvf "$UPLOAD_FILE_NAME" -C ${CONFIG_PATH}/module --exclude "**/_pictures" --exclude "**/examples" --exclude "**/.git" --exclude "**/documentation" --exclude "**/scenario" . 1>/dev/null

# 3. Look Up the Workspace ID
get_remote_token


WORKSPACE_ID=($(curl -s \
  --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://${REMOTE_hostname}/api/v2/organizations/$ORG_NAME/workspaces/$WORKSPACE_NAME \
  | jq -r '.data.id'))

# 4. Create a New Configuration Version

echo '{"data":{"type":"configuration-versions"}}' > ${CONFIG_PATH}/create_config_version.json

UPLOAD_URL=($(curl -s \
  --header "Authorization: Bearer $REMOTE_ORG_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @${CONFIG_PATH}/create_config_version.json \
  https://${REMOTE_hostname}/api/v2/workspaces/$WORKSPACE_ID/configuration-versions \
  | jq -r '.data.attributes."upload-url"'))

# 5. Upload the Configuration Content File

curl -s \
  --header "Content-Type: application/octet-stream" \
  --request PUT \
  --data-binary @${UPLOAD_FILE_NAME} \
  $UPLOAD_URL

# 6. Delete Temporary Files

rm "$UPLOAD_FILE_NAME"
rm ${CONFIG_PATH}/create_config_version.json
