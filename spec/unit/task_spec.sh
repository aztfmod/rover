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
  End
End