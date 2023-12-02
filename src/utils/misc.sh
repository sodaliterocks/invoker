#!/usr/bin/env bash

function check_prog() {
    [[ ! $(command -v "$1") ]] && die "'$1' not installed"
}

function emj() {
    emoji="$1"
    emoji_length=${#emoji}
    echo "$emoji$(eval "for i in {1..$emoji_length}; do echo -n " "; done")"
}

function get_property() {
    file="$1"
    property="$2"

    if [[ -f $file ]]; then
        echo $(grep -oP '(?<=^'"$property"'=).+' $file | tr -d '"')
    fi
}

function repeat() {
    string="$1"
    amount=$2

    if ! [[ -n $amount ]]; then
        amount=20
    fi

    eval "for i in {1..$amount}; do echo -n "$1"; done"
}

function set_property() {
    file=$1
    property=$2
    value=$3

    if [[ -f $file ]]; then
        if [[ -z $(get_property $file $property) ]]; then
            echo "$property=\"$value\"" >> $file
        else
            if [[ $value =~ [[:space:]]+ ]]; then
                value="\"$value\""
            fi

            sed -i "s/^\($property=\)\(.*\)$/\1$value/g" $file
        fi
    fi
}

