#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
    targets = ["rover_local", "rover_registry"]
}

target "rover_local" {
    dockerfile = "./Dockerfile"
    tags = ["rover-local:${tag}"]
    args = {
      versionPowershell    = versionPowershell
      versionKubectl       = versionKubectl
      versionTerraformDocs = versionTerraformDocs
      versionVault         = versionVault
      versionDockerCompose = versionDockerCompose
      versionPacker        = versionPacker
      extensionsAzureCli   = extensionsAzureCli
      versionGolang        = versionGolang
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
    strategy  = strategy
  }
}


variable "tag" {
    default = "latest"
}

variable "strategy" {
    default = ""
}

variable "versionRover" {
    default = ""
}