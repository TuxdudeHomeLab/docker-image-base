#!/usr/bin/env bash

set -e -o pipefail

script_parent_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
git_repo_dir="$(realpath "${script_parent_dir:?}/..")"

ARGS_FILE="${git_repo_dir:?}/config/ARGS"

docker_hub_tags() {
    docker_hub_repo="${1:?}"
    case "${docker_hub_repo:?}" in
        */*) :;; # namespace/repository syntax, leave as is
        *) docker_hub_repo="library/${docker_hub_repo:?}";; # bare repository name (docker official image); must convert to namespace/repository syntax
    esac
    auth_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${docker_hub_repo:?}:pull"
    token="$(curl -fsSL "${auth_url:?}" | jq --raw-output '.token')"
    tags_url="https://registry-1.docker.io/v2/${docker_hub_repo:?}/tags/list"
    curl -fsSL -H "Accept: application/json" -H "Authorization: Bearer ${token:?}" "${tags_url:?}" | jq --raw-output '.tags[]'
}

docker_hub_latest_tag() {
    repo="${1:?}"
    img_pattern="${2:?}"
    docker_hub_tags "${repo:?}" | grep -E "${img_pattern:?}" | sort --version-sort --reverse | head -1
}

get_config_arg() {
    arg="${1:?}"
    sed -n -E "s/^${arg:?}=(.*)\$/\\1/p" ${ARGS_FILE:?}
}

set_config_arg() {
    arg="${1:?}"
    val="${2:?}"
    sed -i -E "s/^${arg:?}=(.*)\$/${arg:?}=${val:?}/" ${ARGS_FILE:?}
}

get_latest_version() {
    arg_prefix="${1:?}"
    img_pattern="${2:?}"
    repo=$(get_config_arg "${arg_prefix:?}_NAME")
    docker_hub_latest_tag "${repo:?}" "${img_pattern:?}"
}

update_latest_version() {
    image_arg_prefix="${1:?}"
    ver=$(get_latest_version ${image_arg_prefix:?})
    echo "Updating ${image_arg_prefix:?} -> ${ver:?}"
    set_config_arg "${image_arg_prefix:?}_TAG" "${ver:?}"
}

upstream_image_arg_prefix="UPSTREAM_IMAGE"
upstream_image_pattern="bookworm-([0-9]+)-slim"

existing_upstream_ver=$(get_config_arg ${upstream_image_arg_prefix:?}_TAG)
latest_upstream_ver=$(get_latest_version "${upstream_image_arg_prefix:?}" "${upstream_image_pattern:?}")

if [[ "${existing_upstream_ver:?}" == "${latest_upstream_ver:?}" ]]; then
    echo "Existing config is already up to date and pointing to the latest upstream debian image version '${latest_upstream_ver:?}'"
else
    echo "Updating ${upstream_image_arg_prefix:?} '${existing_upstream_ver:?}' -> '${latest_upstream_ver:?}'"
    set_config_arg "${upstream_image_arg_prefix:?}_TAG" "${latest_upstream_ver:?}"
    git add ${ARGS_FILE:?}
    git commit -m "feat: Bump upstream debian image version to ${latest_upstream_ver:?} image."
fi

