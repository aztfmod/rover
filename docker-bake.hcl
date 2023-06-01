#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local", "rover_agents"]
}

target "rover_local" {
  dockerfile = "./Dockerfile"
  tags = ["${tag}"]
  args = {
    extensionsAzureCli   = extensionsAzureCli
    versionDockerCompose = versionDockerCompose
    versionGolang        = versionGolang
    versionKubectl       = versionKubectl
    versionKubelogin     = versionKubelogin
    versionPacker        = versionPacker
    versionPowershell    = versionPowershell
    versionRover         = versionRover
    versionTerraform     = versionTerraform
    versionTerraformDocs = versionTerraformDocs
    versionVault         = versionVault
    versionAnsible       = versionAnsible
    versionTerrascan     = versionTerrascan
  }
  platforms = ["linux/amd64","linux/arm64" ]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "rover_registry" {
  inherits = ["rover_local"]
  tags = ["${versionRover}"]
  args = {
    image     = versionRover
  }
}

variable "registry" {
    default = ""
}

variable "tag" {
    default = "latest"
}

variable "versionRover" {
    default = ""
}

variable "versionTerraform" {
    default = ""
}