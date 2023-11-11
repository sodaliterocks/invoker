#!/usr/bin/env bash

_PLUG_INVOKED="true"
base_dir="$(dirname "$(realpath -s "$0")")"
prog_path="$(realpath -s "$0")"
plug_path=""
plug_args=""

shopt -s extglob

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
        die "Value for option --$_PLUG_ARG_PARAM (-$_PLUG_ARG_SHORT) must be a $_PLUG_ARG_TYPE (given: $value)"
    fi
}

function invoke_plug() {
    path="$1"
    args=${@:2}


    if [[ -f "$path" ]]; then
        . "$path"

        if [[ ! -z $args ]]; then
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

                        if [[ ! -z $_PLUG_ARG_SHORT ]]; then
                            param="-$_PLUG_ARG_SHORT, $param"
                        fi

                        if [[ ! -z $_PLUG_ARG_TYPE ]]; then
                            param="$param ($_PLUG_ARG_TYPE)"
                        fi

                        if [[ ! $_PLUG_ARG_PARAM == ex-* ]]; then
                            say "  $param\n    $_PLUG_ARG_HELP"
                        fi

                    done
                fi

                say "  -h, --help"
                say "    Print this help screen"

                exit 0
            else
                for arg in "${_PLUG_ARGS[@]}"; do
                    parse_plug_arg ${arg}

                    if [[ $(echo "$args " | grep -o -P "(--$_PLUG_ARG_PARAM |-$_PLUG_ARG_SHORT )") ]]; then
                        value=$(echo $args | grep -o -P "(?<=--$_PLUG_ARG_PARAM |-$_PLUG_ARG_SHORT ).*?(?:(?= -| --)|$)")

                        if { [[ -z $value ]] || [[ $value == -* ]]; }; then
                            value="true"
                        else
                            value=$(echo $value | xargs)
                        fi

                        test_arg_type "${arg}" "$value"
                        variable="_$(echo $_PLUG_ARG_PARAM | sed s/-/_/g)"
                        eval "${variable}"='${value}' # bite me
                    fi
                done
            fi
        fi

        if [[ $_PLUG_ROOT == "true" && ! $(id -u) = 0 ]]; then
            die "Unauthorized (are you root?)"
        fi

        if [[ $(type -t main) == function ]]; then
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
    die "Need args"
else
    if [[ -f "$1" ]]; then
        plug_path="$(realpath -s "$1")"
        plug_args="${@:2}"
    else
        case $1 in
            "-h"|"--help") echo "help!"; exit 0 ;;
            "-v"|"--version") echo "version!"; exit 0 ;;
            *) die "Cannot find file" ;;
        esac
    fi
fi

if [[ "$prog_path" != "$plug_path" ]]; then
    invoke_plug "$plug_path" $plug_args
fi

#echo "Plug: $plug_path"
#echo "Args: $plug_args"

#echo "Base: $prog_path"

#echo $base_prog
#echo $base_dir
#echo $(basename $cmd)

#echo "-----"

#. $cmd > /dev/null 2>&1
