# Roverlight - Simplified Rover Container

Roverlight is a streamlined version of the rover container focused on essential functionality with modern Docker practices.

## Features
- Multi-stage Docker builds for optimized image size
- Modern GitHub Actions workflows with caching
- Security scanning integration
- Cross-platform support (linux/amd64, linux/arm64)

## Usage
```shell
docker pull ghcr.io/aztfmod/roverlight:latest
```

## Building Locally
Follow these steps to build the roverlight container locally:

1. Clone the repository
```shell
git clone https://github.com/aztfmod/rover
cd rover
```

2. Build using Docker buildx
```shell
docker buildx build -f Dockerfile.roverlight .
```

## CI/CD Pipeline
Roverlight uses modern GitHub Actions workflows:
- Automated builds on push to roverlight branch
- Security scanning with Anchore
- Build metrics tracking
- Multi-architecture support

## Differences from Standard Rover
Roverlight is designed to be a lighter alternative to the standard rover container:
- Focused on essential development tools
- Optimized image size through multi-stage builds
- Simplified configuration

## Environment Variables
The following environment variables are available in the container:
- `TF_DATA_DIR`: Terraform data directory (/home/vscode/.terraform.cache)
- `TF_PLUGIN_CACHE_DIR`: Terraform plugin cache directory (/tf/cache)
- `TF_REGISTRY_DISCOVERY_RETRY`: Number of retries for Terraform registry discovery (5)
- `TF_REGISTRY_CLIENT_TIMEOUT`: Timeout for Terraform registry client (15)
- `ARM_USE_MSGRAPH`: Use Microsoft Graph API (true)

## Container Structure
The container follows a multi-stage build pattern:
1. Builder stage: Initial setup and build dependencies
2. Base stage: Common tools and configurations
3. Final stage: Minimal runtime dependencies

## Security Features
- Security scanning with Anchore
- SARIF report generation
- Critical vulnerability checks
- Automated security reports in PRs
