# Contributing to Rover

Thank you for your interest in contributing to the Azure Terraform SRE Rover project!

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/rover.git`
3. Create a feature branch: `git checkout -b feature/my-new-feature`
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- Docker (for building and testing the rover image)
- Bash 4.0+ (for running and testing scripts)
- ShellSpec (for running unit tests)
- Git (for version control)

### Installing ShellSpec

```bash
curl -fsSL https://git.io/shellspec | sh
```

### Building the Docker Image Locally

```bash
make dev
```

This builds a local development image that you can test with.

### Setting Up the Dev Container

See [DEV_CONTAINER.md](docs/DEV_CONTAINER.md) for detailed instructions on setting up the development container with VS Code.

## Making Changes

### Project Structure

```
rover/
├── scripts/           # Core bash scripts
│   ├── lib/          # Reusable library functions
│   ├── tfcloud/      # Terraform Cloud integration
│   └── ci_tasks/     # CI task definitions
├── agents/           # CI/CD platform agents
├── spec/             # Unit tests
│   └── unit/        # Unit test specs
├── docs/            # Documentation
└── Dockerfile       # Main rover image
```

### Key Scripts

- `scripts/rover.sh` - Main entry point and orchestrator
- `scripts/functions.sh` - Common utility functions
- `scripts/tfstate.sh` - Terraform state management
- `scripts/ci.sh` - Continuous integration workflow
- `scripts/cd.sh` - Continuous deployment workflow
- `scripts/lib/terraform.sh` - Terraform execution wrapper
- `scripts/lib/logger.sh` - Logging and reporting

### Adding New Features

1. **Identify the appropriate location** for your changes
2. **Write tests first** (test-driven development preferred)
3. **Implement the feature** with clear, documented code
4. **Update documentation** to reflect changes
5. **Test thoroughly** including edge cases

## Testing

### Running Unit Tests

Run all tests:
```bash
shellspec
```

Run tests with detailed output:
```bash
shellspec -f d
```

Run specific test file:
```bash
shellspec spec/unit/ci_spec.sh
```

### Writing Tests

Tests are located in `spec/unit/` and follow the ShellSpec framework conventions.

Example test structure:
```bash
Describe 'my_function'
  It 'should return expected value'
    When call my_function "input"
    The output should equal "expected"
    The status should be success
  End
End
```

### Test Coverage

We aim for:
- **All new functions** should have corresponding tests
- **Critical paths** must be tested (state management, terraform execution)
- **Error handling** should be validated

### Manual Testing

1. Build the local image: `make dev`
2. Run the container with your changes
3. Test the affected commands manually
4. Verify logs and output

## Documentation

### Code Documentation

All functions should include documentation headers:

```bash
#
# Function: my_function
# Description: Brief description of what the function does
# Parameters:
#   $1 - Description of first parameter
#   $2 - Description of second parameter
# Returns:
#   0 on success, non-zero on failure
# Example:
#   my_function "param1" "param2"
#
function my_function() {
    # Implementation
}
```

### Documentation Files

When adding or changing functionality:

1. Update relevant documentation in `docs/`
2. Add examples for new features
3. Update README.md if user-facing changes
4. Update USAGE.md for new commands or flags

### Required Documentation Updates

- **New commands**: Update `docs/USAGE.md`
- **CI/CD changes**: Update `docs/CONTINOUS_INTEGRATION.md`
- **Architecture changes**: Update `docs/ARCHITECTURE.md`
- **Breaking changes**: Update `changelog.md`

## Submitting Changes

### Before Submitting

- [ ] All tests pass locally
- [ ] New code has tests
- [ ] Documentation is updated
- [ ] Code follows project style guidelines
- [ ] Commit messages are clear and descriptive
- [ ] No unnecessary files are included

### Pull Request Process

1. **Update your branch** with the latest from main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push to your fork**:
   ```bash
   git push origin feature/my-new-feature
   ```

3. **Create a Pull Request** with:
   - Clear title describing the change
   - Description of what changed and why
   - Reference to any related issues
   - Screenshots/examples if applicable

4. **Address review feedback** promptly

5. **Wait for CI checks** to pass

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing performed
- [ ] All tests pass

## Documentation
- [ ] Documentation updated
- [ ] Inline comments added
- [ ] Examples provided

## Related Issues
Fixes #issue_number
```

## Coding Standards

### Bash/Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode when appropriate: `set -euo pipefail`
- Use meaningful variable names
- Quote variables: `"${variable}"`
- Use functions for reusability
- Add error handling with informative messages
- Use `shellcheck` for linting

### Error Handling

```bash
# Good
if ! some_command; then
    error ${LINENO} "Failed to execute some_command" 1
fi

# Or with error checking
set -e
trap 'error ${LINENO}' ERR
```

### Logging

Use the logger functions from `scripts/lib/logger.sh`:

```bash
debug "Debug message"
information "Info message"
warning "Warning message"
error ${LINENO} "Error message" 1
```

### Variable Naming

- `UPPER_CASE` for environment variables and constants
- `lower_case` for local variables and functions
- Prefix with `TF_VAR_` for Terraform variables
- Use descriptive names

### Function Naming

- Use lowercase with underscores: `my_function_name`
- Use verb prefixes: `get_`, `set_`, `validate_`, `initialize_`
- Keep functions focused and single-purpose

### Comments

- Add function documentation headers (see above)
- Comment complex logic
- Explain "why" not "what" in comments
- Keep comments up to date

### File Organization

- Related functions grouped together
- Source dependencies at the top
- Constants and configuration near the top
- Main execution logic at the bottom

## Development Workflow

### Typical Development Cycle

1. **Identify the issue or feature**
2. **Create a branch**: `git checkout -b feature/my-feature`
3. **Write tests** for the new functionality
4. **Implement the feature** to make tests pass
5. **Run all tests**: `shellspec`
6. **Update documentation**
7. **Commit changes**: `git commit -m "feat: descriptive message"`
8. **Push and create PR**

### Commit Message Format

Follow conventional commits:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Test additions or changes
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Example:
```
feat: add support for custom backend configuration

- Added --backend-config flag to rover CLI
- Updated tfstate.sh to handle custom config
- Added tests for new functionality
```

## Need Help?

- Open an issue for bugs or feature requests
- Join the [Gitter community](https://gitter.im/aztfmod/community)
- Email: tf-landingzones at microsoft dot com

## License

By contributing, you agree that your contributions will be licensed under the project's license.

## Contributor License Agreement

This project requires contributors to sign a Contributor License Agreement (CLA). 
When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and guide you through the process. You only need to do this once across all repos using the Microsoft CLA.

For more information: https://cla.opensource.microsoft.com
