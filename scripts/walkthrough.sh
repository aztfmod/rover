#!/bin/bash

export walkthrough_path="/tf/caf/walkthrough"
export config_name="demo"

function execute_walkthrough {
  # clone_landing_zones

  # clone_configurations

  # select_walkthrough_config

  generate_walkthrough_assets

  # execute_deployments
}

function clone_landing_zones {
  echo -e "\n******************************* Rover Walkthrough *******************************"
  echo "Cloning Logic repository"
  echo " - https://github.com/azure/caf-terraform-landingzones"
  echo ""
  echo "Step one, download the logic repository. This exposes terraform modules for the launchpad and solution landing zones."
  echo -n "Ready to proceed? (y/n): "
  read proceed
  check_exit_case $proceed

  rm -rf ${walkthrough_path}

  set_clone_exports "${walkthrough_path}/landingzones" "/caf_launchpad" "1" "Azure/caf-terraform-landingzones" "master"
  clone_repository

  set_clone_exports "${walkthrough_path}/landingzones" "/caf_solution" "1" "Azure/caf-terraform-landingzones" "master"
  clone_repository
  echo_section_break
}

function clone_configurations {
  echo "Cloning Configuration repository"
  echo " - https://github.com/Azure/caf-terraform-landingzones-starter"
  echo ""
  echo "Step two, download the configuration repository. These contain terraform configuration files for the modules you want to create."
  echo "These are organized by levels for the proper enterprise seperation of concerns."
  echo "Read more about the levels here: https://github.com/Azure/caf-terraform-landingzones/blob/master/documentation/code_architecture/hierarchy.md"
  echo -n "Ready to proceed? (y/n): "
  read proceed
  check_exit_case $proceed

  # set_clone_exports "${walkthrough_path}/configuration" "/configuration" "2" "Azure/caf-terraform-landingzones-starter" "starter"
  set_clone_exports "${walkthrough_path}/configuration" "/configuration" "2" "davesee/caf-terraform-landingzones-starter" "standard_config_tfstate"
  clone_repository
  echo_section_break
}

function select_walkthrough_config {
  echo "The following configurations were found in the starter repo:"
  d=$(pwd)
  cd ${walkthrough_path}/configuration/
  ls -d */ | sort | sed 's/\///'
  cd $d
  echo ""

  config=""
  echo -n "Select one configuration for this walkthrough or 'end' to exit (configuration name): "

  while [ -z $config ]; do
    read config

    if [ $config == "end" ]; then
      echo "Goodbye!"
      exit 0

    elif [ -d "${walkthrough_path}/configuration/$config/" ]; then
      echo ""
      echo "Found configuration, removing the others..."
      find /tf/caf/walkthrough/configuration -maxdepth 1 -mindepth 1 -type d ! -name $config
      find /tf/caf/walkthrough/configuration -maxdepth 1 -mindepth 1 -type d ! -name $config -exec rm -rf {} +

      export config_name=$config
      echo_section_break
    else
      echo "Configuration '$config' not found, please try again (configuration name): "
    fi
  done
}

function generate_walkthrough_assets {
  echo -n "Would you like to generate the deployment/destroy scripts and README instructions? (y/n): "
  read proceed
  check_exit_case $proceed

  rm -f ${walkthrough_path}/deploy.sh ${walkthrough_path}/destroy.sh ${walkthrough_path}/README.md

  write_md "# Deployment Steps"
  init_sh

  index=0
  for path in $(find ${walkthrough_path}/configuration/${config_name} -type f \( -name "configuration.tfvars" -o -name "landingzone.tfvars" \) | sort); do
    config_array[$index]="$(get_level_string $path):$path"
    ((index += 1))
  done

  IFS=$'\n' sorted_ascending=($(sort <<<"${config_array[*]}"))
  unset IFS

  for i in "${sorted_ascending[@]}"; do
    level_a=$(echo $i | awk 'BEGIN {FS=":"}{print $1}')
    config_a=$(echo $i | awk 'BEGIN {FS=":"}{print $2}')
    echo "rover commands generated for $level_a deployment for $(basename ${config_a%\/*})"

    write_doc ${config_a%\/*}
    write_bash_apply ${config_a%\/*}
  done

  IFS=$'\n' sorted_descending=($(sort -r <<<"${config_array[*]}"))
  unset IFS

  for i in "${sorted_descending[@]}"; do
    level_d=$(echo $i | awk 'BEGIN {FS=":"}{print $1}')
    config_d=$(echo $i | awk 'BEGIN {FS=":"}{print $2}')
    write_bash_destroy ${config_d%\/*}
  done

  end_sh
}

function execute_deployments {
  echo ""
  echo "Deployment script and instructions generated!"
  echo_section_break
  echo "You can follow the README instructions to deploy one configuration at a time or run deploy.sh to deploy ALL configurations in sequence."
  echo "Please note the base folder names are used to name the *.tfstate files and must match the configuration landingzone.tf references."
  echo "${walkthrough_path}/deploy.sh"
  echo "${walkthrough_path}/README.md"
  echo ""
  echo "This deployment creates all resources in the currently logged in Azure subscription"
  echo "and is the final step, but will take a while to run."
  echo -n "Ready to proceed? (y/n): "
  read proceed
  check_exit_case $proceed

  bash ${walkthrough_path}/deploy.sh &
}

function get_level_string {
  var_folder=$1

  start=$(echo $var_folder | grep -b -o "level" | awk 'BEGIN {FS=":"}{print $1}')
  level="level${var_folder:$(expr $start + 5):1}"

  echo $level
}

function write_doc {
  local var_folder=$1

  local level=$(get_level_string "$var_folder")

  write_md "## Deploy $level $(basename $var_folder)"
  write_md "\`\`\`bash"
  write_md "rover \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_md "  -launchpad \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_md "  -lz ${walkthrough_path}/landingzones/caf_launchpad \\" || write_md "  -lz ${walkthrough_path}/landingzones/caf_solution \\"
  write_md "  -var-folder $var_folder \\"
  write_md "  -tfstate $(basename $var_folder).tfstate \\"
  write_md "  -level $level \\"
  write_md "  -env ${config_name} \\"
  write_md "  -a [ apply | destroy | plan ]"
  write_md "\`\`\`"
}

function write_bash_apply {
  local var_folder=$1

  local level=$(get_level_string "$var_folder")

  write_sh "# Deploy $level $(basename $var_folder)"
  write_sh "bash /tf/rover/rover.sh \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_sh "-lz ${walkthrough_path}/landingzones/caf_launchpad \\" || write_sh "-lz ${walkthrough_path}/landingzones/caf_solution \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_sh "-launchpad \\"
  write_sh "-var-folder $var_folder \\"
  write_sh "-tfstate $(basename $var_folder).tfstate \\"
  write_sh "-level $level \\"
  write_sh "-env ${config_name} \\"
  write_sh "-a apply &"
  write_sh "wait\n"
}

function write_bash_destroy {
  local var_folder=$1

  local level=$(get_level_string "$var_folder")

  write_sh_destroy "# Deploy $level $(basename $var_folder)"
  write_sh_destroy "bash /tf/rover/rover.sh \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_sh_destroy "-lz ${walkthrough_path}/landingzones/caf_launchpad \\" || write_sh_destroy "-lz ${walkthrough_path}/landingzones/caf_solution \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_sh_destroy "-launchpad \\"
  write_sh_destroy "-var-folder $var_folder \\"
  write_sh_destroy "-tfstate $(basename $var_folder).tfstate \\"
  write_sh_destroy "-level $level \\"
  write_sh_destroy "-env ${config_name} \\"
  write_sh_destroy "-a destroy &"
  write_sh_destroy "wait\n"
}

function init_sh {
  write_sh "#!/bin/bash\n\nfunction main {\n"
  write_sh_destroy "#!/bin/bash\n\nexport tf_approve=--auto-approve\n\nfunction main {\n"
}

function end_sh {
  write_sh "}\n\nmain"
  write_sh_destroy "}\n\nmain"
  chmod +x ${walkthrough_path}/deploy.sh ${walkthrough_path}/destroy.sh
}

function write_md {
  echo -e $1 >>${walkthrough_path}/README.md
}

function write_sh {
  echo -e $1 >>${walkthrough_path}/deploy.sh
}

function write_sh_destroy {
  echo -e $1 >>${walkthrough_path}/destroy.sh
}

function echo_section_break {
  echo -e "\n*********************************************************************************"
}

function check_exit_case {
  local proceed=$1

  if [ $proceed != "y" ]; then
    echo "Goodbye!"
    exit 0
  fi
}
