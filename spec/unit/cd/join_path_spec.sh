Describe 'cd.sh'
  Include scripts/cd.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh

  Describe "join_path"

    It 'should handle base path with no ending slash'
      When call join_path "a/b" "c"
      The output should include 'a/b/c'        
    End

    It 'should handle base path with an ending slash'
      When call join_path "a/b/" "c"
      The output should include 'a/b/c'        
    End

    It 'should handle a part with a leading slash and basepath with ending slash'
      When call join_path "a/b/" "/c"
      The output should include 'a/b/c'        
    End


    It 'should handle a part with a leading slash and basepath with no ending slash '
      When call join_path "a/b" "/c"
      The output should include 'a/b/c'        
    End

    It 'should handle a part with no leading slash and basepath with ending slash'
      When call join_path "a/b/" "c"
      The output should include 'a/b/c'        
    End


    It 'should handle a part with no leading slash and basepath with no ending slash '
      When call join_path "a/b" "c"
      The output should include 'a/b/c'        
    End

  End
End