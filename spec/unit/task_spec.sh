Describe 'task.sh'
  Include scripts/task.sh
  Describe "get_list_of_task"
    #Function Mocks
    error() {
        local parent_lineno="$1"
        local message="$2"
        >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        return ${code}
    }

    Context "Invalid CI Task Dir Provided"

      It 'should return an error that the path to symphony.yml is not provided'
        When call get_list_of_task './bogus_ci_dir/'
        The error should eq 'Error line:1: message:Invalid CI Directory path, ./bogus_ci_dir/ not found. status :1'
        The status should eq 1
      End
    End

    Context "Detect 2 tasks"
        It 'should return no errors if task.yml files exist in the provided directory path'
          When call get_list_of_task 'spec/harness/ci_tasks/'
          The output should eq 'spec/harness/ci_tasks/task1.yml spec/harness/ci_tasks/task2.yml spec/harness/ci_tasks/task3.yml'
          The status should eq 0
        End
      End
  End

  Describe "format_task_parameters"
    Context "Invalid Json"

      It 'should return an error that the JSON is invalid'
        When call format_task_parameters "Invalid Json"
        The error should eq 'parse error: Invalid numeric literal at line 1, column 8'
        The output should eq ''
      End
    End

    Context "Valid Json without prefix"

      It 'should return valid parameters'
        When call format_task_parameters $(get_task_parameters_json spec/harness/ci_tasks/task1.yml)
        The error should eq ''
        The output should eq 'config1=value1'
      End
    End

    Context "Valid Json w/ prefix"

      It 'should return valid parameters with prefix'
        When call format_task_parameters $(get_task_parameters_json spec/harness/ci_tasks/task2.yml)
        The error should eq ''
        The output should eq '--config2=value2'
      End
    End
  End
End