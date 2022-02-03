#!/usr/bin/env bash
set -e

args_file_as_build_args() {
    local prefix=""
    if [[ "$1" == "docker-flags" ]]; then
        prefix="--build-arg "
        while IFS="=" read -r key value; do
            echo -n "${prefix}$key=\"$value\" "
        done < "args"
    else
        while IFS="=" read -r key value; do
            echo "$key=$value"
        done < "args"
    fi
}

packages_to_install() {
    while IFS="=" read -r key value; do
        echo -n "$key=$value "
    done < "packages-to-install"
}

packages_to_remove() {
    while IFS="=" read -r key; do
        echo -n "$key "
    done < "packages-to-remove"
}

if [[ "$1" == "docker-flags" ]]; then
    # --build-arg format used with the docker build command.
    args_file_as_build_args $1
    echo -n "--build-arg PACKAGES_TO_INSTALL=\"$(packages_to_install)\" "
    echo -n "--build-arg PACKAGES_TO_REMOVE=\"$(packages_to_remove)\""
else
    # Github Env format dump.
    args_file_as_build_args
    echo "PACKAGES_TO_INSTALL=$(packages_to_install)"
    echo "PACKAGES_TO_REMOVE=$(packages_to_remove)"
fi