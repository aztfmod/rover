#
# Rover Build Automation Makefile
# 
# This Makefile provides targets for building rover container images for different
# environments and platforms. All targets use the build_image.sh script with
# different parameters to generate appropriate container images.
#
# Usage:
#   make [target]           # Build for specific target
#   make help              # Show available targets and usage
#
# Available targets:
#   github (default)       # Build image for GitHub Actions
#   local                  # Build local development image
#   dev                    # Build development image
#   ci                     # Build CI/CD optimized image  
#   alpha                  # Build alpha/preview image
#
# Variables:
#   arch                   # Target architecture (e.g., Linux/amd64, Linux/arm64)
#   agent                  # CI/CD agent type (github, azdo, gitlab, etc.)
#
# Examples:
#   make                   # Build default GitHub image
#   make local             # Build local development image
#   make local arch=Linux/amd64  # Build for specific architecture
#   make dev agent=azdo    # Build Azure DevOps development agent
#

# Set default target to github if no target is specified
default: github

#
# Target: github
# Description: Build rover image optimized for GitHub Actions workflows
# Output: Container image tagged for GitHub Actions usage
# Usage: make github
#
github:
	@echo "Building rover image for GitHub Actions..."
	@bash "$(CURDIR)/scripts/build_image.sh" "github"

#
# Target: local
# Description: Build rover image for local development and testing
# Parameters:
#   arch (optional) - Target architecture (e.g., Linux/amd64, Linux/arm64)
#   agent (optional) - CI/CD agent type to include
# Output: Local container image for development use
# Usage: 
#   make local                    # Build for current architecture
#   make local arch=Linux/amd64   # Build for specific architecture (e.g., M1 Mac building x64)
#   make local agent=azdo        # Build with Azure DevOps agent
#
local:
	@echo "Building local rover image..."
	@echo "Architecture: ${arch}"
	@echo "Agent: ${agent}"
	@bash "$(CURDIR)/scripts/build_image.sh" "local" ${arch} ${agent}

#
# Target: dev  
# Description: Build rover image for development with additional debugging tools
# Parameters:
#   arch (optional) - Target architecture
#   agent (optional) - CI/CD agent type to include
# Output: Development container image with enhanced tooling
# Usage: make dev
#
dev:
	@echo "Building development rover image..."
	@bash "$(CURDIR)/scripts/build_image.sh" "dev" ${arch} ${agent}

#
# Target: ci
# Description: Build rover image optimized for CI/CD pipelines
# Output: Container image optimized for continuous integration workflows
# Usage: make ci
#
ci:
	@echo "Building CI-optimized rover image..."
	@bash "$(CURDIR)/scripts/build_image.sh" "ci"

#
# Target: alpha
# Description: Build rover alpha/preview image with latest features
# Output: Preview container image for testing unreleased features
# Usage: make alpha
#
alpha:
	@echo "Building rover alpha/preview image..."
	@bash "$(CURDIR)/scripts/build_image.sh" "alpha"

#
# Target: help
# Description: Display help information about available targets
# Usage: make help
#
help:
	@echo ""
	@echo "Rover Build System"
	@echo "=================="
	@echo ""
	@echo "Available targets:"
	@echo "  github (default)  Build image for GitHub Actions"
	@echo "  local            Build local development image"
	@echo "  dev              Build development image with debugging tools"
	@echo "  ci               Build CI/CD optimized image"
	@echo "  alpha            Build alpha/preview image"
	@echo "  help             Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  arch=<value>     Target architecture (Linux/amd64, Linux/arm64)"
	@echo "  agent=<value>    CI/CD agent type (github, azdo, gitlab, tfc)"
	@echo ""
	@echo "Examples:"
	@echo "  make                          # Build default GitHub image"
	@echo "  make local                    # Build local development image"
	@echo "  make local arch=Linux/amd64   # Build for x64 (useful on M1 Macs)"
	@echo "  make dev agent=azdo          # Build Azure DevOps development image"
	@echo ""
	@echo "For more information, see: docs/CONTRIBUTING.md"
	@echo ""

#
# Target: clean
# Description: Clean up build artifacts and temporary files
# Usage: make clean
#
clean:
	@echo "Cleaning build artifacts..."
	@docker system prune -f
	@docker image prune -f
	@echo "Clean complete."

#
# Target: test
# Description: Run tests against built images
# Usage: make test
#
test:
	@echo "Running rover image tests..."
	@bash "$(CURDIR)/scripts/test_runner.sh"

.PHONY: default github local dev ci alpha help clean test