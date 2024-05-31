#!/usr/bin/env bash
# Usage:
#   prepare-release.sh
#   prepare-release.sh v0.1.1

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
    echo "${1:?}" | sed -E 's#^v([0-9]+)\.([0-9]+)\.([0-9]+)-.+$#v\1.\2.\3#g' | awk -F. -v OFS=. '{$NF += 1 ; print}'
}

get_package_version() {
    get_config_arg "${1:?}"
}

pkg="Debian"
tag_pkg="debian"
config_arg_pkg_version="UPSTREAM_IMAGE_TAG"

if [ -z "$1" ]; then
    # Generate the next semantic version number if version number is not supplied.
    rel_ver="$(get_next_semantic_ver $(get_latest_tag))"
else
    # Use the supplied version number from the command line arg.
    rel_ver="${1:?}"
fi
pkg_ver="$(get_package_version ${config_arg_pkg_version:?})"

echo "Creating tag ${rel_ver:?}-${pkg_ver:?}"
git githubtag -m "${rel_ver:?} release based off ${pkg:?} ${pkg_ver:?}." ${rel_ver:?}-${pkg_ver:?}
