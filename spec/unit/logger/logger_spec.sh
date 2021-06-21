Describe 'logger.sh'
  Include scripts/functions.sh
  Include scripts/lib/logger.sh
  
  Describe "__log_init__"
    #Function Mocks
    export TEST_DEBUG_CREATE_DIR=true
    error() {
        local parent_lineno="$1"
        local message="$2"
        local code="$3"
        >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        export TEST_DEBUG_CREATE_DIR=false
        return ${code}
    }
    __create_dir__ (){
      if [ "$TEST_DEBUG_CREATE_DIR" == "true" ]; then
        echo "creating directory $1"
      fi
    }

    Context "Log Path Not Set"
      It 'should throw an error and not create directory'
        When call __log_init__
        The error should include 'Error line:0: message:Log folder path is not set status :1'  
      End
    End

    Context "Log Path is Set"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
      }
      BeforeEach 'setup'


      It 'should throw an error and not create directory'
        When call __log_init__
        The error should eq ""
        The output should include "creating directory $log_folder_path"
      End
    End

  End
End