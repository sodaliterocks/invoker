#!/usr/bin/env bash

shopt -s extglob

base_dir="$(dirname "$(realpath -s "$0")")"
prog_path="$(realpath -s "$0")"
plug_path=""
plug_args=""

_PLUG_INVOKED="true"

. "$base_dir/utils/misc.sh"

function say() {
	color=""
    message="${@:2}"
    output=""
    prefix=""
    style="0"

    if [[ "$2" != "" ]]; then
    	message="$2"
    	type="$1"
    else
    	message="$1"
    fi

    case $1 in
        debug)
            color="35"
            prefix="Debug"
            ;;
        error)
            color="31"
            prefix="Error"
            style="1"
            ;;
        info)
            color="34"
            style="1"
            ;;
        primary)
            color="37"
            style="1"
            ;;
        warning)
            color="33"
            style="1"
            ;;
        *|default)
            color="0"
            message="$@"
            ;;
    esac

    if [[ $prefix == "" ]]; then
        output="\033[${style};${color}m${message}\033[0m"
    else
        output="\033[1;${color}m${prefix}"

        if [[ $message == "" ]]; then
            output+="!"
        else
            output+=": \033[${style};${color}m${message}\033[0m"
        fi

        output+="\033[0m"
    fi

    echo -e "$output"
}

function die() {
    say error "$@"
    exit 255
}

function parse_plug_arg() {
    IFS=";" read -r -a arg_array <<< "${@}"

    _PLUG_ARG_PARAM="${arg_array[0]}"
    _PLUG_ARG_SHORT="${arg_array[1]}"
    _PLUG_ARG_HELP="${arg_array[2]}"
    _PLUG_ARG_TYPE="${arg_array[3]}"
    _PLUG_ARG_DEFAULT="${arg_array[4]}"
}

function say_help() {
    say "Sodalite Invoker"
    say "  (No description)"
    say "\nUsage:"
    say "  $0 [plug] [plug-options]"
    say "  $0 [options]"
    say "\nOptions:"
    say "  -h, --help"
    say "    Print this help screen"
    exit 0
}

function test_arg_type() {
    arg="$1"
    value="$2"
    valid="true"

    parse_plug_arg "${arg}"

    function test_value() {
        pattern=$2
        value="$1"

        case $value in
            $pattern) echo "true" ;;
            *) echo "false" ;;
        esac
    }

    case $_PLUG_ARG_TYPE in
        "bool"|"boolean") valid=$(test_value "$value" '@(true|false)') ;;
        "int"|"integer"|"number") valid=$(test_value "$value" '@(+([0-9]))')
    esac

    if [[ $valid == "false" ]]; then
        die_message="Value for option --$_PLUG_ARG_PARAM "
        [[ $_PLUG_ARG_SHORT != "" ]] && die_message+="(-$_PLUG_ARG_SHORT) "
        die_message+="must be $_PLUG_ARG_TYPE (given: $value)"
        die "$die_message"
    fi
}

function invoke_plug() {
    path="$1"
    args=${@:2}

    if [[ -f "$path" ]]; then
        . "$path"

          if [[ $args == "--help" || $args == "-h" ]]; then
              [[ -z $_PLUG_TITLE ]] && _PLUG_TITLE="$(basename "$path")"
              [[ -z $_PLUG_DESCRIPTION ]] && _PLUG_DESCRIPTION="(No description)"

              say "$_PLUG_TITLE"
              say "  $_PLUG_DESCRIPTION"
              say "\nUsage:"
              say "  $(basename "$path") [options]"
              say "\nOptions:"

              if [[ ! -z $_PLUG_ARGS ]]; then
                  for arg in "${_PLUG_ARGS[@]}"; do
                      parse_plug_arg ${arg}

                      param="--$_PLUG_ARG_PARAM"
                      help="$_PLUG_ARG_HELP"

                      if [[ ! -z $_PLUG_ARG_SHORT ]]; then
                          param="-$_PLUG_ARG_SHORT, $param"
                      fi

                      if [[ ! -z $_PLUG_ARG_TYPE ]]; then
                          param="$param [$_PLUG_ARG_TYPE]"
                      fi

                      if [[ $_PLUG_ARG_DEFAULT != "" ]]; then
                          help="$help (default: $_PLUG_ARG_DEFAULT)"
                      fi

                      print_arg_help=true

                      if [[ $SODALITE_INVOKER_SHOW_EXPERIMENTAL_HELP == "true" ]]; then
                          if [[ $_PLUG_ARG_PARAM == ex-* ]]; then
                              if [[ $_PLUG_ARG_HELP == "" ]]; then
                                  print_arg_help=false
                              fi
                          fi
                      else
                          if [[ $_PLUG_ARG_PARAM == ex-* ]]; then
                              print_arg_help=false
                          fi
                      fi

                      if [[ $print_arg_help == true ]]; then
                          say "  $param\n    $help"
                      fi
                  done
              fi

              say "  -h, --help"
              say "    Print this help screen"

              exit 0
          else
              for arg in "${_PLUG_ARGS[@]}"; do
                  parse_plug_arg ${arg}

                  variable="_$(echo $_PLUG_ARG_PARAM | sed s/-/_/g)"
                  value=""

                  if [[ $(echo "$args " | grep -o -P "(--$_PLUG_ARG_PARAM |-$_PLUG_ARG_SHORT )") ]]; then
                      value=$(echo $args | grep -o -P "(?<=--$_PLUG_ARG_PARAM |-$_PLUG_ARG_SHORT ).*?(?:(?= -| --)|$)")

                      if { [[ -z $value ]] || [[ $value == -* ]]; }; then
                          value="true"
                      else
                          value=$(echo $value | xargs)
                      fi

                      test_arg_type "${arg}" "$value"
                  fi

                  if [[ "$_PLUG_ARG_DEFAULT" != "" ]] && [[ $value == "" ]]; then
                      value="$_PLUG_ARG_DEFAULT"
                      test_arg_type "${arg}" "$value"
                  fi

                  eval "${variable}"='${value}' # bite me
              done
          fi

        if [[ $_PLUG_ROOT == "true" && ! $(id -u) = 0 ]]; then
            die "Unauthorized (are you root?)"
        fi

        if [[ $(type -t main) == function ]]; then
            _PLUG_PATH="$path"
            _PLUG_PASSED_ARGS="$args"

            main

            [[ ! $? -eq 0 ]] && exit $?
        else
            echo "Plugin '$(basename "$path")' has no entrypoint (needs main())"
        fi
    else
        die "Cannot find file"
    fi
}

if [[ $@ == "" ]]; then
    say_help
else
    if [[ -f "$1" ]]; then
        plug_path="$(realpath -s "$1")"
        plug_args="${@:2}"
    else
        case $1 in
            "-h"|"--help") say_help ;;
            *) die "Cannot find file" ;;
        esac
    fi
fi

if [[ "$prog_path" != "$plug_path" ]]; then
    invoke_plug "$plug_path" $plug_args
fi
