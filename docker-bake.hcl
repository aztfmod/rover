#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local", "roverlight", "rover_agents"]
}

target "rover_local" {
  dockerfile = "./Dockerfile"
  tags = ["rover_local:latest"]
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
    versionTfupdate      = versionTfupdate
  }
  platforms = ["linux/arm64", "linux/amd64" ]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "roverlight" {
  dockerfile = "./Dockerfile.roverlight"
  tags = ["ghcr.io/arnaudlh/roverlight:latest"]
  args = {
    versionRover = "${versionRover}"
    USERNAME = "vscode"
    TARGETOS = "linux"
    TARGETARCH = "amd64"
  }
  platforms = ["${platform}"]
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


# Docker build configuration
variable "registry" {
  default = "ghcr.io/aztfmod"
}

variable "image_name" {
  default = "roverlight"
}

variable "version" {
  default = "latest"
}

variable "platform" {
  default = "linux/amd64"
}

# Version configuration
variable "versionRover" {
  default = ""
}

variable "versionTerraform" {
  default = ""
}

# Build arguments
variable "targetarch" {
  default = "amd64"
}

variable "username" {
  default = "vscode"
}
