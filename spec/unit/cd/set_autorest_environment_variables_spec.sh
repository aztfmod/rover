Describe 'cd.sh'
  Include scripts/cd.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh

  Describe "set_autorest_environment_variables"

    Context "AZURE_ENVIRONMENT == AzureCloud"
      setup() {
        export AZURE_ENVIRONMENT="AzureCloud"
      }
      BeforeEach 'setup'

      It 'should set AZURE_ENVIRONMENT to AzurePublicCloud'
        When call set_autorest_environment_variables
        The variable AZURE_ENVIRONMENT should equal "AzurePublicCloud"       
      End
    End

    Context "AZURE_ENVIRONMENT == AzureCloud"
      setup() {
        export AZURE_ENVIRONMENT="AzureUSGovernment"
      }
      BeforeEach 'setup'

      It 'should set AZURE_ENVIRONMENT to AzureUSGovernmentCloud'
        When call set_autorest_environment_variables
        The variable AZURE_ENVIRONMENT should equal "AzureUSGovernmentCloud"       
      End
    End

  End
End