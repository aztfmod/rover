#
# Cleanup the command sent to terraform when using destroy with a plan
# support bash and zsh
#
function parse_command_destroy_with_plan {
  max=0
  return_args=""
  case $(ps -p$$ -ocmd=) in
    *bash*) i=0; read -a args <<< $@; max=${#args[@]}; shopt -s extglob ;;
    /usr/bin/zsh) i=1; read -A args <<< $@; max=$((${#args[@]}+1)) ;;
  esac

  while [ $i -le $max ]
  do
      case "${args[$i]}" in
          *-var-file=*) ;;
          -var-file) i=$((i + 1));;
          -var) i=$((i + 1));;
          *) return_args+="${args[$i]} ";;
      esac
      i=$((i + 1))
  done

  case $(ps -p$$ -ocmd=) in
    bash) i=0; read -a args <<< $@; max=${#args[@]}; shopt -u extglob ;;
  esac

  echo ${return_args}
}


function purge_command {
  PARAMS=''
  case "${1}" in
    graph)
      shift 1
      purge_command_graph $@
      ;;
    plan)
      shift 1
      purge_command_plan $@
      ;;
  esac

  echo $PARAMS
}

function purge_command_graph {
  while (( "$#" )); do
    case "${1}" in
      -var-file)
        shift 2
        ;;
      *)
        PARAMS+="${1} "
        shift 1
        ;;
    esac
  done
}


function purge_command_plan {
  while (( "$#" )); do
    case "${1}" in
      -draw-cycles)
        shift 1
        ;;
      "-type"*)
        shift 1
        ;;
      *)
        PARAMS+="${1} "
        shift 1
        ;;
    esac
  done
}
