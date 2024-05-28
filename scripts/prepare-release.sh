#!/usr/bin/env bash

set -e -o pipefail

script_parent_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
git_repo_dir="$(realpath "${script_parent_dir:?}/..")"

ARGS_FILE="${git_repo_dir:?}/config/ARGS"

get_config_arg() {
    arg="${1:?}"
    sed -n -E "s/^${arg:?}=(.*)\$/\\1/p" ${ARGS_FILE:?}
}

get_latest_tag() {
    git tag --list | sort --version-sort --reverse | head -1
}

get_next_semantic_ver() {
    echo "${1:?}" | awk -F. -v OFS=. '{$NF += 1 ; print}'
}

get_image_version() {
    get_config_arg "${1:?}"
}

if [ -z "$1" ]; then
    # Generate the next semantic version number if version number is not supplied.
    rel_ver="$(get_next_semantic_ver $(get_latest_tag))"
else
    # Use the supplied version number from the command line arg.
    rel_ver="${1:?}"
fi
upstream_image_ver="$(get_image_version UPSTREAM_IMAGE_TAG)"

echo "Creating tag ${rel_ver:?}-${tag_pkg}-${upstream_image_ver:?}"
git githubtag -m "New release based off ${upstream_image_ver:?} upstream image." ${rel_ver:?}-${upstream_image_ver:?}
