#!/usr/bin/env bash

function check_prog() {
    [[ ! $(command -v "$1") ]] && die "'$1' not installed"
}

function emj() {
    emoji="$1"
    emoji_length=${#emoji}
    echo "$emoji$(eval "for i in {1..$emoji_length}; do echo -n " "; done")"
}
