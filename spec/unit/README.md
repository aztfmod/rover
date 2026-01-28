# Unit Tests for Rover

This directory contains unit tests for the Rover bash scripts using the [ShellSpec](https://github.com/shellspec/shellspec) testing framework.

## Table of Contents

- [Installation](#installation)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Test Coverage](#test-coverage)
- [Test Structure](#test-structure)
- [Best Practices](#best-practices)

## Installation

### Install Shellspec

We use the unit testing framework [shellspec](https://github.com/shellspec/shellspec). To install shellspec on your local system run:

```bash
curl -fsSL https://git.io/shellspec | sh
```

Or if you prefer to install to a specific directory:

```bash
curl -fsSL https://git.io/shellspec | sh -s -- --prefix ~/.local
```

### Verify Installation

```bash
shellspec --version
```

## Running Tests

### Run All Tests

From the root of the project in bash run:

```bash
shellspec
```

### Run with Detailed Output

To get more detailed output run:

```bash
shellspec -f d
```

### Run Specific Test File

To run a specific test file:

```bash
shellspec spec/unit/functions_spec.sh
```

### Run with Code Coverage

To generate code coverage reports (requires kcov):

```bash
shellspec --kcov
```

### Available Output Formats

- `-f progress` - Progress bar (default)
- `-f documentation` (or `-f d`) - Detailed documentation format
- `-f tap` - TAP format
- `-f junit` - JUnit XML format
- `-f failures` - Show only failures

## Writing Tests

### Test File Structure

Test files should:
- Be located in `spec/unit/`
- Have the suffix `_spec.sh`
- Match the name of the script being tested (e.g., `functions.sh` → `functions_spec.sh`)

### Basic Test Template

```bash
Describe 'my_script.sh'
  Include scripts/my_script.sh

  Describe "my_function"
    It 'should do something'
      When call my_function "arg1" "arg2"
      The output should equal "expected output"
      The status should be success
    End
  End
End
```

### Test Structure Elements

#### Describe Block
Groups related tests together:
```bash
Describe 'Feature Name'
  # Tests go here
End
```

#### Context Block
Provides context for a specific scenario:
```bash
Context "when input is valid"
  # Tests for valid input
End
```

#### It Block
Defines a single test case:
```bash
It 'should return success'
  When call my_function
  The status should be success
End
```

#### Setup and Teardown

Use `BeforeEach` and `AfterEach` for test setup and cleanup:

```bash
Describe "my_function"
  setup() {
    export TEST_VAR="value"
    mkdir -p /tmp/test
  }
  
  teardown() {
    rm -rf /tmp/test
  }
  
  BeforeEach 'setup'
  AfterEach 'teardown'
  
  It 'should use TEST_VAR'
    When call my_function
    The output should include "$TEST_VAR"
  End
End
```

### Assertions

Common assertion patterns:

```bash
# Output assertions
The output should equal "exact match"
The output should include "partial match"
The output should match pattern "regex.*pattern"
The output should be blank
The output should not be blank

# Status assertions
The status should be success
The status should be failure
The status should eq 0
The status should eq 1

# Error output assertions
The error should include "error message"
The error should be blank

# File assertions
The path "/tmp/file" should be exist
The path "/tmp/file" should not be exist
The path "/tmp/file" should be file
The path "/tmp/dir" should be directory
```

### Mocking Functions

Mock external dependencies to isolate tests:

```bash
Describe "function_that_calls_az_cli"
  # Mock az command
  az() {
    echo '{"name": "test-resource"}'
    return 0
  }
  
  It 'should parse az output'
    When call function_that_calls_az_cli
    The output should include "test-resource"
  End
End
```

### Mocking Exit

To test error functions that call `exit`:

```bash
Describe "error_function"
  # Override exit to prevent test termination
  exit() {
    return $1
  }
  
  It 'should exit with error code'
    When call error_function "error message"
    The error should include "error message"
    The status should eq 1
  End
End
```

### Testing with Temporary Files

```bash
Describe "file_processing"
  setup() {
    TEST_DIR="/tmp/test_$$"
    mkdir -p "$TEST_DIR"
    echo "test content" > "$TEST_DIR/test.txt"
  }
  
  teardown() {
    rm -rf "$TEST_DIR"
  }
  
  BeforeEach 'setup'
  AfterEach 'teardown'
  
  It 'should process file'
    When call process_file "$TEST_DIR/test.txt"
    The output should include "test content"
  End
End
```

### Skip Tests

Skip tests conditionally:

```bash
It 'should work on Linux only'
  Skip if "not on Linux" [ "$(uname)" != "Linux" ]
  When call linux_specific_function
  The status should be success
End
```

## Test Coverage

### Current Coverage

As of the latest update:

| Script | Test File | Status |
|--------|-----------|--------|
| ci.sh | ci_spec.sh | ✓ Tested |
| task.sh | task_spec.sh | ✓ Tested |
| symphony_yaml.sh | symphony_spec.sh | ✓ Tested |
| functions.sh | functions_spec.sh | ✓ Tested |
| tfstate.sh | tfstate_spec.sh | ✓ Tested |
| logger.sh | logger_spec.sh | ✓ Tested |
| cd.sh | execute_cd_spec.sh | ✓ Partially |
| rover.sh | - | ✗ Not tested |
| remote.sh | - | ✗ Not tested |
| lib/terraform.sh | - | ✗ Not tested |
| lib/azure_ad.sh | - | ✗ Not tested |
| lib/parse_parameters.sh | - | ✗ Not tested |

### Coverage Goals

- **Critical functions**: 100% coverage (state management, terraform execution)
- **Core utilities**: 80%+ coverage (error handling, parameter parsing)
- **Helper functions**: 60%+ coverage

### Measuring Coverage

To measure code coverage, install kcov:

```bash
# Ubuntu/Debian
sudo apt-get install kcov

# macOS
brew install kcov
```

Then run tests with coverage:

```bash
shellspec --kcov --kcov-options "--include-path=scripts --exclude-pattern=spec,coverage"
```

Coverage reports will be in `coverage/index.html`.

## Test Structure

```
spec/
├── spec_helper.sh          # Shared test utilities
├── harness/                # Test fixtures and data
│   ├── symphony.yml       # Sample configuration files
│   └── ...
└── unit/                   # Unit tests
    ├── README.md          # This file
    ├── ci_spec.sh         # CI tests
    ├── task_spec.sh       # Task tests
    ├── functions_spec.sh  # Functions tests
    ├── tfstate_spec.sh    # State management tests
    ├── logger_spec.sh     # Logger tests
    ├── cd/                # CD-related tests
    │   ├── execute_cd_spec.sh
    │   ├── verify_cd_parameters_spec.sh
    │   └── ...
    └── ...
```

## Best Practices

### 1. Test One Thing at a Time

Each test should verify a single behavior:

```bash
# Good
It 'should parse valid input'
  When call parse_input "valid"
  The output should equal "parsed"
End

# Bad - testing multiple things
It 'should parse input and save to file'
  When call parse_and_save "valid" "file.txt"
  The output should equal "parsed"
  The path "file.txt" should be exist
End
```

### 2. Use Descriptive Test Names

```bash
# Good
It 'should return error code 1 when file does not exist'

# Bad
It 'returns error'
```

### 3. Isolate Tests

Use mocks to avoid dependencies on external systems:

```bash
# Mock Azure CLI
az() {
  echo '{"id": "test-id"}'
  return 0
}
```

### 4. Clean Up After Tests

Always clean up temporary files and resources:

```bash
AfterEach 'cleanup'

cleanup() {
  rm -rf "$TEST_DIR"
  unset TEST_VAR
}
```

### 5. Test Error Cases

Don't just test the happy path:

```bash
Context "when file does not exist"
  It 'should return error'
    When call process_file "/nonexistent"
    The error should include "not found"
    The status should be failure
  End
End
```

### 6. Use Meaningful Assertions

```bash
# Good
The output should include "Successfully deployed"

# Less helpful
The status should be success
```

### 7. Group Related Tests

```bash
Describe "error handling"
  Context "when parameter is missing"
    # Test missing parameter
  End
  
  Context "when parameter is invalid"
    # Test invalid parameter
  End
End
```

## Debugging Tests

### Run with Debug Output

```bash
shellspec -f d --debug
```

### Print Debug Information

```bash
It 'should do something'
  Debug "Testing with value: $TEST_VAR"
  When call my_function "$TEST_VAR"
  The output should include "expected"
End
```

### Run Specific Examples

Use `--example` or `-e` to run tests matching a pattern:

```bash
shellspec -e "should return error"
```

### Focus on Specific Tests

Use `fit` instead of `It` to focus on specific tests (temporarily):

```bash
fit 'should do something important'
  # This test will run, others will be skipped
End
```

## Continuous Integration

Tests are automatically run in CI pipelines. Ensure:

1. All tests pass before submitting PR
2. New code includes tests
3. Coverage doesn't decrease

## Additional Resources

- [ShellSpec Documentation](https://github.com/shellspec/shellspec)
- [ShellSpec Examples](https://github.com/shellspec/shellspec/tree/master/examples)
- [Contributing Guide](../../CONTRIBUTING.md)
- [Architecture Documentation](../../docs/ARCHITECTURE.md)

## Getting Help

If you need help writing tests:

1. Check existing test files for examples
2. Read the ShellSpec documentation
3. Ask in the [Gitter community](https://gitter.im/aztfmod/community)
4. Open an issue with the `testing` label