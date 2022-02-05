#!/usr/bin/env bash
set -e

ARGS_FILE="config/ARGS"

get_packages() {
    while IFS="=" read -r key value; do
        echo -n "$key "
    done < "packages-to-install"
}

get_cmd() {
    echo -n "apt-get -qq update && apt list 2>/dev/null $(get_packages) | sed -E 's#([^ ]+)/[^ ]+ ([^ ]+) .+#\1=\2#g'"
}

get_image_name() {
    local image_name=""
    local image_tag=""
    while IFS="=" read -r key value; do
        if [[ "$key" == "UPSTREAM_IMAGE_NAME" ]]; then
            image_name="$value"
        elif [[ "$key" == "UPSTREAM_IMAGE_TAG" ]]; then
            image_tag="$value"
        fi
    done < ${ARGS_FILE:?}
    echo -n "${image_name:?}:${image_tag:?}"
}

updated_list=$(docker run --rm "$(get_image_name)" sh -c "$(get_cmd)" | grep -v 'Listing...')
echo "$updated_list" > packages-to-install
