#!/usr/bin/env bash
set -e

args_file_as_build_args() {
    local prefix=""
    if [[ "$1" == "docker-flags" ]]; then
        prefix="--build-arg "
    fi
    while IFS="=" read -r key value; do
        echo -n "${prefix}$key=\"$value\" "
    done < "args"
}

packages_to_install_file_as_build_arg() {
    local prefix=""
    if [[ "$1" == "docker-flags" ]]; then
        prefix="--build-arg "
    fi
    echo -n "${prefix}PACKAGES_TO_INSTALL=\""
    while IFS="=" read -r key value; do
        echo -n "$key=$value "
    done < "packages-to-install"
    echo -n "\""
}

packages_to_remove_file_as_build_arg() {
    local prefix=""
    if [[ "$1" == "docker-flags" ]]; then
        prefix="--build-arg "
    fi
    echo -n "${prefix}PACKAGES_TO_REMOVE=\""
    while IFS="=" read -r key; do
        echo -n "$key "
    done < "packages-to-remove"
    echo -n "\""
}

echo "$(args_file_as_build_args $1)$(packages_to_install_file_as_build_arg $1) $(packages_to_remove_file_as_build_arg $1)"
