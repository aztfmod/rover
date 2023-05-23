tfcloud_runs_cancel() {
  if [[ "${run_id}" != "null" ]] && [[ ! -z "${run_id:-}" ]]; then
    information "@calling runs_cancel"

    warning "Cancelling Terraform Cloud run: ${run_id}"

    BODY=$( jq -c -n \
      --arg comment "${1}" \
      '
        {
          "comments": "$comment"
        }
      ' ) && debug " - body: $BODY"

    url="https://${TF_VAR_tf_cloud_hostname}/api/v2/runs/${run_id}/actions/cancel"
    body=$(make_curl_request -url "$url" -options "--request POST" -data "${BODY}" -gracefully_continue)
  else
    information "No terraform cloud runs found."
  fi
}