#!/usr/bin/env bash

function check_prog() {
    [[ ! $(command -v "$1") ]] && die "'$1' not installed"
}
