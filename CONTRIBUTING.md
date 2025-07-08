# Contributing to Rover

We welcome contributions to the Azure Terraform SRE Rover project! This guide will help you get started with contributing to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Development Environment Setup](#development-environment-setup)
- [Contributing Workflow](#contributing-workflow)
- [Code Standards](#code-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Standards](#documentation-standards)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Development Environment Setup

### Prerequisites

- Docker Desktop
- Git
- Visual Studio Code (recommended)
- Azure CLI (for testing)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/aztfmod/rover.git
   cd rover
   ```

2. **Build local development image**
   ```bash
   make dev
   ```

3. **Set up Dev Container (recommended)**
   - Open the project in VS Code
   - Install the "Remote - Containers" extension
   - Command Palette → "Remote-Containers: Reopen in Container"

4. **Alternative: Run locally**
   ```bash
   # Build and run rover locally
   make local
   docker run -it --rm rover-local:latest
   ```

### Project Structure

```
rover/
├── scripts/              # Main shell scripts and rover logic
│   ├── rover.sh          # Main entry point
│   ├── functions.sh      # Core utility functions  
│   ├── lib/              # Library functions
│   └── ci_tasks/         # CI/CD task definitions
├── docs/                 # Documentation
├── agents/               # CI/CD agent configurations
├── .devcontainer/        # VS Code dev container config
├── Dockerfile            # Main container definition
└── Makefile              # Build automation
```

## Contributing Workflow

### 1. Issue Creation

Before making changes:
- Check existing issues for duplicates
- Create a new issue describing the problem or feature
- Discuss the approach with maintainers if it's a significant change

### 2. Branch and Development

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Test your changes

# Commit with clear messages
git commit -m "feat: add new landing zone validation"
```

### 3. Commit Message Format

We follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New features
- `fix`: Bug fixes  
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

## Code Standards

### Shell Script Guidelines

1. **Header Documentation**
   ```bash
   #!/bin/bash
   #
   # Description: Brief description of script purpose
   # Usage: script_name.sh [options]
   # Author: Your Name
   # Last Modified: Date
   #
   ```

2. **Function Documentation**
   ```bash
   #
   # Function: function_name
   # Description: What the function does
   # Parameters:
   #   $1 - Parameter description
   #   $2 - Parameter description  
   # Returns: Description of return value
   # Example: function_name "param1" "param2"
   #
   function_name() {
       # Function implementation
   }
   ```

3. **Error Handling**
   - Always check return codes for critical operations
   - Use proper error messages with context
   - Exit with appropriate error codes

4. **Variable Naming**
   - Use lowercase with underscores: `my_variable`
   - Use uppercase for environment variables: `MY_ENV_VAR`
   - Prefix local variables in functions: `local my_local_var`

5. **Code Style**
   - Use 4 spaces for indentation
   - Keep lines under 120 characters
   - Use meaningful variable and function names
   - Add comments for complex logic

### Dockerfile Guidelines

- Use official base images when possible
- Minimize layers and image size
- Document installation steps with comments
- Use multi-stage builds where appropriate
- Set appropriate user permissions

## Testing Guidelines

### Running Tests

```bash
# Run all tests
./scripts/test_runner.sh

# Run specific test suite
shellspec spec/unit/

# Run with coverage
shellspec --kcov
```

### Writing Tests

1. **Test File Structure**
   ```bash
   # spec/unit/my_feature_spec.sh
   Describe "My Feature"
     It "should perform expected behavior"
       When call my_function "input"
       The output should equal "expected_output"
       The status should be success
     End
   End
   ```

2. **Test Categories**
   - Unit tests for individual functions
   - Integration tests for script workflows
   - End-to-end tests for complete scenarios

3. **Test Best Practices**
   - Test both success and failure scenarios
   - Use descriptive test names
   - Keep tests isolated and independent
   - Mock external dependencies

## Documentation Standards

### Markdown Guidelines

- Use clear, concise language
- Include code examples for complex concepts
- Add table of contents for longer documents
- Use consistent heading structure
- Include links to related documentation

### Code Documentation

- Document all public functions and scripts
- Include usage examples
- Explain complex algorithms or logic
- Update documentation when changing code

## Pull Request Process

### Before Submitting

1. **Code Review Checklist**
   - [ ] Code follows project standards
   - [ ] Tests pass locally
   - [ ] Documentation updated
   - [ ] No sensitive information committed
   - [ ] Commit messages follow convention

2. **Testing Checklist**
   - [ ] Unit tests added/updated
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   - [ ] No breaking changes (or properly documented)

### PR Submission

1. **Create Pull Request**
   - Use descriptive title
   - Reference related issues
   - Include detailed description of changes
   - Add screenshots for UI changes

2. **PR Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Code refactoring

   ## Testing
   - [ ] Tests added/updated
   - [ ] Manual testing completed

   ## Related Issues
   Fixes #123
   ```

### Review Process

1. **Automated Checks**
   - CI/CD pipeline must pass
   - Code quality checks must pass
   - Security scans must pass

2. **Human Review**
   - At least one maintainer approval required
   - Address all review feedback
   - Maintain clean commit history

3. **Merge**
   - Squash commits if multiple small commits
   - Use merge commit for feature branches
   - Delete feature branch after merge

## Getting Help

### Communication Channels

- **Issues**: GitHub Issues for bugs and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **Gitter**: [aztfmod/community](https://gitter.im/aztfmod/community) for real-time chat
- **Email**: tf-landingzones@microsoft.com for direct contact

### Resources

- [Azure Terraform Documentation](https://aka.ms/caf/terraform)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Azure Cloud Adoption Framework](https://docs.microsoft.com/azure/cloud-adoption-framework/)

## License Agreement

Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately. Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

---

Thank you for contributing to Rover! 🚀