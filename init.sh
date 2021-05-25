#!/bin/bash

export caf_environment=demo

function main() {
  # Downnload zones and demo configs to demo
  rm -rf /tf/caf/${caf_environment}
  bash /tf/rover/rover.sh --clone-sample "demo" &
  wait

  echo -n "Would you like to generate the Deployment script and instructions? (y/n): "
  read proceed

  [[ $proceed != "y" ]] && exit

  # Create sample readme
  write_md "# Deployment Steps"
  init_sh

  # Write the rover command for each configuration set
  for line in $(find /tf/caf/${caf_environment}/configs -type f \( -name "configuration.tfvars" -o -name "landingzone.tfvars" \) | sort); do
    #TODO: find out tfstate
    # grep -R "tfstate = \"" /tf/caf/demo/configs/demo/ | sort

    write_rover ${line%\/*}
    write_bash ${line%\/*}
  done

  end_sh
}

function write_rover() {
  local var_folder=$1

  start=$(echo $var_folder | grep -b -o "level" | awk 'BEGIN {FS=":"}{print $1}')
  level="level${var_folder:$(expr $start + 5):1}"

  write_md "## Deploy $level: $(basename $var_folder)"
  write_md "\`\`\`bash"
  write_md "rover \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_md "  -launchpad \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_md "  -lz /tf/caf/${caf_environment}/landingzones/caf_launchpad \\" || write_md "  -lz /tf/caf/${caf_environment}/landingzones/caf_solution \\"
  write_md "  -var-folder $var_folder \\"
  write_md "  -level $level \\"
  write_md "  -env ${caf_environment} \\"
  write_md "  -a apply"
  write_md "\`\`\`"
}

function write_bash() {
  local var_folder=$1

  start=$(echo $var_folder | grep -b -o "level" | awk 'BEGIN {FS=":"}{print $1}')
  level="level${var_folder:$(expr $start + 5):1}"

  write_sh "# Deploy $level $(basename $var_folder)"
  write_sh "bash /tf/rover/rover.sh \\"
  [[ $(basename $var_folder) = "launchpad" ]] && write_sh "  -lz /tf/caf/${caf_environment}/landingzones/caf_launchpad \\" || write_sh "  -lz /tf/caf/${caf_environment}/landingzones/caf_solution \\"
  write_sh " -var-folder $var_folder \\"
  write_sh " -level $level \\"
  write_sh " -env ${caf_environment} \\"
  write_sh " -a apply"
  write_sh "wait"
}

function init_sh() {
  write_sh "#!/bin/bash\n\nfunction main() {\n"
}

function end_sh() {
  write_sh "}\nmain"
  chmod +x /tf/caf/${caf_environment}/deploy.sh
}

function write_md() {
  echo -e $1 >>/tf/caf/${caf_environment}/README.md
}

function write_sh() {
  echo -e $1 >>/tf/caf/${caf_environment}/deploy.sh
}

main
