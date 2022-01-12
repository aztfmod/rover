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
}

target "rover_registry" {
  inherits = ["rover_local"]
  tags = ["${versionRover}"]
  args = {
    image     = versionRover
    strategy  = strategy
  }
}

# Todo
# need to implement the various type of rover_registry as sent by the command_line context

target "rover_gitlab" {
  inherits = ["rover_registry"]
  dockerfile = "./agents/gitlab/Dockerfile"
  tags = ["docker.io/aztfmod/roveragent:${tag}-gitlab"]
  args = {
    image     = versionRover
    USERNAME  = USERNAME
  }
}

target "rover_azure_devops" {
  inherits = ["rover_registry"]
  dockerfile = "./agents/gitlab/azure_devops/Dockerfile"
  tags = ["docker.io/aztfmod/roveragent:${tag}-azure_devops"]
  args = {
    image       = versionRover
    USERNAME    = USERNAME
    versionAzdo = versionAzdo
  }
}

target "rover_github" {
  inherits = ["rover_registry"]
  dockerfile = "./agents/gitlab/github/Dockerfile"
  tags = ["docker.io/aztfmod/roveragent:${tag}-github"]
  args = {
    image               = versionRover
    versionGithubRunner = versionGithubRunner
    USERNAME            = USERNAME
  }
}

target "rover_tfc" {
  inherits = ["rover_registry"]
  dockerfile = "./agents/gitlab/tfc/Dockerfile"
  tags = ["docker.io/aztfmod/roveragent:${tag}-tfc"]
  args = {
    image       = versionRover
    versionTfc  = versionTfc
    USERNAME    = USERNAME
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