#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local", "roverlight"]
}

target "rover_local" {
  dockerfile = "./Dockerfile"
  tags = ["rover_local:${tag}"]
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
  tags = [
    "ghcr.io/${registry}/roverlight:${tag}",
    "ghcr.io/${registry}/roverlight:latest"
  ]
  args = {
    versionRover = versionRover
  }
  platforms = ["linux/arm64", "linux/amd64" ]
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

# The tag variable is used to set the tag for the Docker image.
variable "tag" {
  default = "latest"
}

# The versionRover variable is used to set the version of the Rover.
variable "versionRover" {
  default = ""
}

# The versionTerraform variable is used to set the version of Terraform.
variable "versionTerraform" {
  default = ""
}
