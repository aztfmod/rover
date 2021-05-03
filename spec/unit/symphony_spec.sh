Describe 'symphony_yaml.sh'
  Include scripts/symphony_yaml.sh
      get_landingzone_path_for_stack() {
        echo "./temp_lz_dir/"
      }

      get_config_path_for_stack() {
        echo "./temp_config_dir/"
      }

      setup() {
        mkdir "./temp_lz_dir/"
        mkdir "./temp_config_dir/"

        touch ./temp_lz_dir/main.tf
        touch temp_config_dir/configuration.tfvars

        export symphony_yaml_file="spec/harness/symphony.yml"
        export base_directory="."
      }

      teardown() {
        rm -rf ./temp_lz_dir/
        rm -rf ./temp_config_dir/
      }

  Context "check_landing_zone_path_exists"

    Before 'setup'
    After 'teardown'

    It 'should return no errors and test that ./temp_lz_dir/ exists.'
      When call check_landing_zone_path_exists $symphony_yaml_file 'lvl' 'stack'
      The output should include 'true'
      The error should eq ''
      The status should eq 0
    End
  End

  Context "check_configuration_path_exists"

    Before 'setup'
    After 'teardown'

    It 'should return no errors and test that ./temp_lz_dir/ exists.'
      When call check_configuration_path_exists $symphony_yaml_file 'lvl' 'stack'
      The output should include 'true'
      The error should eq ''
      The status should eq 0
    End
  End

  Context "check_tfvars_exists"

    Before 'setup'
    After 'teardown'

    It 'should return no errors and test ./spec/harness/configs/level0/launchpad/configuration.tfvars exists.'
      When call check_tfvars_exists $symphony_yaml_file 'level0' 'launchpad'
      The output should include 'true'
      The error should eq ''
      The status should eq 0
    End
  End

  Context "check_tf_exists"

    Before 'setup'
    After 'teardown'

    It 'should return no errors and test ./spec/harness/landingzones/launchpad/main.tf exists.'
      When call check_tf_exists $symphony_yaml_file 'level0' 'launchpad'
      The output should include 'true'
      The error should eq ''
      The status should eq 0
    End
  End
End