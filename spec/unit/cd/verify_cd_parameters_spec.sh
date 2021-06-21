Describe 'cd.sh'
  Include scripts/cd.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh

  Describe "verify_cd_parameters"
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
        echo "here*******"
    }

    Context "run action & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should handle known cd run'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform run'        
        The status should eq 0
      End
    End

    Context "run action & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="apply"
      }
      BeforeEach 'setup'

      It 'should handle known cd apply'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform apply'        
        The status should eq 0
      End
    End

    Context "run action & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="plan"
      }
      BeforeEach 'setup'

      It 'should handle known cd plan'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform plan'        
        The status should eq 0
      End
    End

    Context "test action & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="test"
      }
      BeforeEach 'setup'

      It 'should handle known cd test'
        When call verify_cd_parameters
        The output should include 'Found valid cd action test'        
        The status should eq 0
      End
    End   

    Context "rover deploy -h & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="-h"
      }
      BeforeEach 'setup'

      It 'should show help usage'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Usage:'
        The error should include 'rover deploy <action> <flags>' 
        The status should eq 0
      End
    End   

    Context "rover cd run -h & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="run"
        export PARAMS="-h "
      }
      BeforeEach 'setup'

      It 'should show help usage'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Usage:'
        The error should include 'rover deploy <action> <flags>' 
        The status should eq 0
      End
    End  

    Context "invalid action & valid Symphony Yaml Provided"
      setup() {
        export symphony_yaml_file="spec/harness/symphony.yml"
        export cd_action="bad_action"
      }

      BeforeEach 'setup'

      It 'should handle show an error message for invalid cd actions'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Invalid cd action bad_action'
        The output should include 'Escape code: 1'
      End
    End   

    Context "rover cd only"
      setup() {
        unset symphony_yaml_file
        export cd_action="bad_action"
      }

      BeforeEach 'setup'

      It 'show usage if rover cd is called'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Invalid cd action bad_action'
        The status should eq 1
      End
    End    

  End
End