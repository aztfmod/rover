Describe 'functions.sh'
  Include scripts/functions.sh

  Describe "error"
    # Override exit to prevent test termination
    exit() {
      return $1
    }

    Context "Error with message and line number"
      setup() {
        export LOG_TO_FILE="false"
        export backend_type_hybrid="azurerm"
      }
      BeforeEach 'setup'

      It 'should output error message and exit with specified code'
        When call error 42 "Test error message" 2
        The error should include "Error"
        The error should include "on or near line 42"
        The error should include "Test error message"
        The status should eq 2
      End
    End

    Context "Error without message"
      setup() {
        export LOG_TO_FILE="false"
        export backend_type_hybrid="azurerm"
      }
      BeforeEach 'setup'

      It 'should output error with line number only'
        When call error 100 "" 1
        The error should include "on or near line 100"
        The status should eq 1
      End
    End
  End

  Describe "parameter_value"
    Context "Valid parameter value"
      It 'should return the parameter value'
        When call parameter_value "--level" "level2"
        The output should eq "level2"
        The status should be success
      End
    End

    Context "Invalid parameter value (flag)"
      # Mock error function to prevent exit
      error() {
        echo "Error: Value not set for parameter $2"
        return 1
      }

      It 'should error when value is a flag'
        When call parameter_value "--level" "--another-flag"
        The output should include "Error"
        The output should include "Value not set"
        The status should eq 1
      End
    End
  End

  Describe "execute_with_backoff"
    Context "Command succeeds on first attempt"
      test_command() {
        return 0
      }

      It 'should execute successfully without retry'
        When call execute_with_backoff test_command
        The status should be success
      End
    End

    Context "Command fails then succeeds"
      attempt_counter=0
      test_failing_command() {
        attempt_counter=$((attempt_counter + 1))
        if [ $attempt_counter -lt 2 ]; then
          return 1
        fi
        return 0
      }

      setup() {
        attempt_counter=0
        export ATTEMPTS=3
        export TIMEOUT=1
      }
      BeforeEach 'setup'

      It 'should retry and eventually succeed'
        When call execute_with_backoff test_failing_command
        The status should be success
        The error should include "Retrying"
      End
    End

    Context "Command always fails"
      test_always_fails() {
        return 1
      }

      setup() {
        export ATTEMPTS=2
        export TIMEOUT=1
      }
      BeforeEach 'setup'

      It 'should fail after max attempts'
        When call execute_with_backoff test_always_fails
        The status should eq 1
        The error should include "Hit the max retry count"
      End
    End
  End

  Describe "display_login_instructions"
    It 'should display login instructions'
      When call display_login_instructions
      The output should include "To login the rover to azure"
      The output should include "rover login"
      The output should include "rover logout"
      The status should be success
    End
  End

  Describe "process_actions"
    # Mock functions that process_actions calls
    bootstrap() { echo "bootstrap called"; exit 0; }
    ignite() { echo "ignite called"; exit 0; }
    init() { echo "init called"; exit 0; }
    workspace() { echo "workspace called"; exit 0; }
    execute_walkthrough() { echo "walkthrough called"; exit 0; }
    clone_repository() { echo "clone called"; exit 0; }
    landing_zone() { echo "landing_zone called"; exit 0; }
    verify_parameters() { echo "verify_parameters called"; }
    deploy() { echo "deploy called"; }
    register_ci_tasks() { echo "register_ci_tasks called"; }
    verify_ci_parameters() { echo "verify_ci_parameters called"; }
    set_default_parameters() { echo "set_default_parameters called"; }
    execute_ci_actions() { echo "execute_ci_actions called"; }
    verify_cd_parameters() { echo "verify_cd_parameters called"; }
    execute_cd() { echo "execute_cd called"; }
    run_integration_tests() { echo "run_integration_tests called"; }
    display_instructions() { echo "display_instructions called"; }

    Context "bootstrap command"
      setup() {
        export caf_command="bootstrap"
      }
      BeforeEach 'setup'

      It 'should call bootstrap function'
        When call process_actions
        The output should include "bootstrap called"
        The status should be success
      End
    End

    Context "init command"
      setup() {
        export caf_command="init"
      }
      BeforeEach 'setup'

      It 'should call init function'
        When call process_actions
        The output should include "init called"
        The status should be success
      End
    End

    Context "ci command"
      setup() {
        export caf_command="ci"
      }
      BeforeEach 'setup'

      It 'should execute CI workflow'
        When call process_actions
        The output should include "register_ci_tasks called"
        The output should include "verify_ci_parameters called"
        The output should include "set_default_parameters called"
        The output should include "execute_ci_actions called"
        The status should be success
      End
    End

    Context "cd command"
      setup() {
        export caf_command="cd"
      }
      BeforeEach 'setup'

      It 'should execute CD workflow'
        When call process_actions
        The output should include "verify_cd_parameters called"
        The output should include "set_default_parameters called"
        The output should include "execute_cd called"
        The status should be success
      End
    End

    Context "unknown command"
      setup() {
        export caf_command="unknown_command"
      }
      BeforeEach 'setup'

      It 'should call display_instructions'
        When call process_actions
        The output should include "display_instructions called"
        The status should be success
      End
    End
  End
End
