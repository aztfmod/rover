Describe 'cd.sh'
  Include scripts/cd.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh

  Describe "execute_cd"
    #Function Mocks

    validate_symphony () {
      echo ""
    }

    escape () {
      echo "Escape code: $1"
    }

    error() {
        # local parent_lineno="$1"
        # local message="$2"
        # >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        # return ${code}
        echo ""
    }

      get_config_path_for_stack() {
        echo "foo"
      }

      get_state_file_name_for_stack() {
        echo "bar"
      }

      get_integration_test_path() {
        echo "integration_test_path"
      }

      get_all_level_names() {
        echo "level1"
      }

      get_all_stack_names_for_level() {
        echo "foundations"
      }

      get_landingzone_path_for_stack() {
        echo "caf_modules_public/landingzones/caf_foundations/"
      }

      deploy() {
        export deploy_called=true
        echo "deploy called with: $1"
      }

      set_autorest_environment_variables () {
        export set_autorest_environment_variables_called=true
      }

      run_integration_tests (){
        export run_integration_tests_called=true
        echo "run_integration_tests called with: $1"
      }

    Context "cd action == run"
      setup() {
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should call deploy and run tests'
        When call execute_cd
        The output should include '@Starting CD execution'
        The variable deploy_called should equal true
        The variable set_autorest_environment_variables_called should equal true
        The variable run_integration_tests_called should equal true
      End
    End

    Context "cd action == apply"
      setup() {
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="apply"
      }
      BeforeEach 'setup'

      It 'should call deploy and not run tests'
        When call execute_cd
        The output should include '@Starting CD execution'
        The variable deploy_called should equal true
        The variable set_autorest_environment_variables_called should equal false
        The variable run_integration_tests_called should equal false
      End
    End    

    Context "cd action == test"
      setup() {
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="test"
      }
      BeforeEach 'setup'

      It 'should run tests and not call deploy'
        When call execute_cd
        The output should include '@Starting CD execution'
        The variable deploy_called should equal false
        The variable set_autorest_environment_variables_called should equal true
        The variable run_integration_tests_called should equal true
      End
    End    

    Context "cd action == run, workspace=test1workspace"
      setup() {
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should call deploy with the specified workspace'
        When call execute_cd
        The output should include 'deploy called with: test1workspace'
        The variable deploy_called should equal true
        The variable set_autorest_environment_variables_called should equal true
        The variable run_integration_tests_called should equal true        
      End
    End  

    Context "cd action == apply, workspace=test1workspace"
      setup() {
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="apply"
      }
      BeforeEach 'setup'

      It 'should call deploy with the specified workspace'
        When call execute_cd
        The output should include 'deploy called with: test1workspace'
        The variable deploy_called should equal true
        The variable set_autorest_environment_variables_called should equal false
        The variable run_integration_tests_called should equal false  
      End
    End   

    Context "cd action == run, workspace=test1workspace"
      setup() {
        export base_directory="base_dir/"
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="all"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should call run_integration_tests with the correct test path'
        When call execute_cd
        The output should include 'run_integration_tests called with: base_dir/integration_test_path'
      End
    End      

    Context "level=0"
      setup() {
        export base_directory="base_dir/"
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="level0"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should set caf_command to launchpad'
        When call execute_cd
        The variable caf_command should equal "launchpad"
        The output should include '@Starting CD execution'
      End
    End    


    Context "level=1"
      setup() {
        export base_directory="base_dir/"
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="level1"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should set caf_command to landingzone'
        When call execute_cd
        The variable caf_command should equal "landingzone"
        The output should include '@Starting CD execution'
      End
    End    

    Context "level=1 cd_action=plan"
      setup() {
        export base_directory="base_dir/"
        export TF_VAR_workspace="test1workspace"
        export deploy_called=false
        export run_integration_tests_called=false
        export set_autorest_environment_variables_called=false

        export TF_VAR_level="level1"
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="plan"
      }
      BeforeEach 'setup'

      It 'should set tf_action to plan'
        When call execute_cd
        The variable tf_action should equal "plan"
        The output should include '@Starting CD execution'
      End
    End    

  End
End