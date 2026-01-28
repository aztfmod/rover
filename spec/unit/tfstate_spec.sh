Describe 'tfstate.sh'
  Include scripts/tfstate.sh

  Describe "tfstate_cleanup"
    setup() {
      # Create test directory structure
      export TF_DATA_DIR="/tmp/test_tfstate_$$"
      export landingzone_name="/tmp/test_lz_$$"
      mkdir -p "$landingzone_name"
      mkdir -p "$TF_DATA_DIR"
      
      # Create test files
      touch "$landingzone_name/backend.hcl.tf"
      touch "$landingzone_name/backend.hcl"
      touch "$landingzone_name/caf.auto.tfvars"
      touch "$TF_DATA_DIR/terraform.tfstate"
    }

    teardown() {
      rm -rf "$landingzone_name"
      rm -rf "$TF_DATA_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'teardown'

    It 'should remove all backend configuration files'
      When call tfstate_cleanup
      The path "$landingzone_name/backend.hcl.tf" should not be exist
      The path "$landingzone_name/backend.hcl" should not be exist
      The path "$landingzone_name/caf.auto.tfvars" should not be exist
      The path "$TF_DATA_DIR/terraform.tfstate" should not be exist
      The status should be success
    End
  End

  Describe "tfstate_configure"
    setup() {
      export script_path="/home/runner/work/rover/rover/scripts"
      export landingzone_name="/tmp/test_lz_$$"
      mkdir -p "$landingzone_name"
    }

    teardown() {
      rm -rf "$landingzone_name"
    }

    BeforeEach 'setup'
    AfterEach 'teardown'

    Context "azurerm backend"
      It 'should configure Azure Storage backend'
        Skip if "backend templates may not exist in test environment" true

        When call tfstate_configure "azurerm"
        The output should include "@tfstate_configure"
        The output should include "azurerm"
        The status should be success
      End
    End

    Context "remote backend"
      setup_remote() {
        export TF_var_folder=""
        export TF_VAR_environment="test"
        export TF_VAR_level="level1"
        export TF_VAR_tf_name="test.tfstate"
        export TF_VAR_tf_cloud_organization="testorg"
        export TF_VAR_tf_cloud_hostname="app.terraform.io"
      }
      BeforeEach 'setup_remote'

      It 'should configure Terraform Cloud backend'
        Skip if "backend templates may not exist in test environment" true

        When call tfstate_configure "remote"
        The output should include "@tfstate_configure"
        The output should include "remote"
        The status should be success
      End
    End

    Context "unsupported backend"
      # Mock error function
      error() {
        echo "Error: Backend type not supported: $2"
        return $3
      }
      # Mock tfstate_cleanup
      tfstate_cleanup() {
        echo "cleanup called"
      }

      It 'should error on unsupported backend type'
        When call tfstate_configure "unsupported_backend"
        The output should include "cleanup called"
        The output should include "Error: Backend type not supported"
        The status should eq 3001
      End
    End
  End

  Describe "terraform_init"
    # Mock the backend-specific init functions
    terraform_init_azurerm() {
      echo "terraform_init_azurerm called"
    }
    terraform_init_remote() {
      echo "terraform_init_remote called"
    }

    Context "azurerm backend"
      setup() {
        export gitops_terraform_backend_type="azurerm"
      }
      BeforeEach 'setup'

      It 'should call azurerm init function'
        When call terraform_init
        The output should include "@calling terraform_init"
        The output should include "azurerm"
        The output should include "terraform_init_azurerm called"
        The status should be success
      End
    End

    Context "remote backend"
      setup() {
        export gitops_terraform_backend_type="remote"
      }
      BeforeEach 'setup'

      It 'should call remote init function'
        When call terraform_init
        The output should include "@calling terraform_init"
        The output should include "remote"
        The output should include "terraform_init_remote called"
        The status should be success
      End
    End

    Context "unsupported backend"
      setup() {
        export gitops_terraform_backend_type="unsupported"
      }
      BeforeEach 'setup'

      # Mock error function
      error() {
        echo "Error: Backend type not supported: $2"
        return $3
      }

      It 'should error on unsupported backend type'
        When call terraform_init
        The output should include "Error: Backend type not supported"
        The status should eq 3002
      End
    End
  End

  Describe "initialize_state"
    # Mock required functions
    check_subscription_required_role() {
      echo "Permission check for $1"
    }
    tfstate_cleanup() {
      echo "Cleanup called"
    }
    plan() {
      echo "Plan called"
    }
    apply() {
      echo "Apply called"
    }
    destroy() {
      echo "Destroy called"
    }

    # Mock terraform command
    terraform() {
      echo "Terraform $1 executed"
      return 0
    }

    setup() {
      export skip_permission_check=false
      export landingzone_name="/tmp/test_lz_$$"
      export TF_DATA_DIR="/tmp/test_tfstate_$$"
      export TF_VAR_level="level0"
      export TF_VAR_workspace="test"
      export terraform_version="1.0.0"
      export tf_action="plan"
      
      mkdir -p "$landingzone_name"
      mkdir -p "$TF_DATA_DIR"
    }

    teardown() {
      rm -rf "$landingzone_name"
      rm -rf "$TF_DATA_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'teardown'

    Context "with permission check"
      It 'should check permissions and initialize'
        When call initialize_state
        The output should include "@calling initialize_state"
        The output should include "Checking required permissions"
        The output should include "Permission check"
        The output should include "Cleanup called"
        The status should be success
      End
    End

    Context "skip permission check"
      setup_skip() {
        export skip_permission_check=true
      }
      BeforeEach 'setup_skip'

      It 'should skip permission check'
        When call initialize_state
        The output should include "Checking required permissions - Skipped"
        The status should be success
      End
    End

    Context "plan action"
      setup_plan() {
        export tf_action="plan"
      }
      BeforeEach 'setup_plan'

      It 'should call plan function'
        When call initialize_state
        The output should include "calling plan"
        The output should include "Plan called"
        The status should be success
      End
    End

    Context "apply action"
      setup_apply() {
        export tf_action="apply"
      }
      BeforeEach 'setup_apply'

      It 'should call apply function'
        When call initialize_state
        The output should include "calling apply"
        The output should include "Apply called"
        The status should be success
      End
    End

    Context "destroy action"
      setup_destroy() {
        export tf_action="destroy"
      }
      BeforeEach 'setup_destroy'

      It 'should call destroy function'
        When call initialize_state
        The output should include "calling destroy"
        The output should include "Destroy called"
        The status should be success
      End
    End
  End
End
