#!/bin/bash

export caf_environment=demo

function main() {

  # DOWNLOAD

  # DEPLOY
  # Launchpad
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_launchpad -launchpad -var-folder /tf/caf/sample/configs/demo/level0/launchpad -level level0 -env ${caf_environment} -a apply &
  wait

  # Platform
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate caf_foundations.tfstate -var-folder /tf/caf/sample/configs/demo/level1 -level level1 -env ${caf_environment} -a apply &
  wait

  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate networking_hub.tfstate -var-folder /tf/caf/sample/configs/demo/level2/networking/hub -level level2 -env ${caf_environment} -a apply &
  wait
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate caf_shared_services.tfstate -var-folder /tf/caf/sample/configs/demo/level2/shared_services -level level2 -env ${caf_environment} -a apply &
  wait

  # Sample Apps
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate landing_zone_aks.tfstate -var-folder /tf/caf/sample/configs/demo/level3/aks -level level3 -env ${caf_environment} -a apply &
  wait
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate landing_zone_app_svc.tfstate -var-folder /tf/caf/sample/configs/demo/level3/app_service -level level3 -env ${caf_environment} -a apply &
  wait
  bash /tf/rover/rover.sh -lz /tf/caf/sample/landingzones/caf_solution -tfstate landing_zone_aml.tfstate -var-folder /tf/caf/sample/configs/demo/level3/data_analytics/101-aml-workspace -level level3 -env ${caf_environment} -a apply &
  wait

}

main
