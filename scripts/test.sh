#!/usr/bin/env bash

set -e -o pipefail

random_container_name() {
    shuf -zer -n10  {A..Z} {a..z} {0..9} | tr -d '\0'
}

container_type="base"
container_name=$(random_container_name)

echo "Starting ${container_type:?} container ${container_name:?} to run tests in the foreground ..."
docker run \
    --name ${container_name:?} \
    --rm \
    ${IMAGE:?} \
    sh -c \
    'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install nginx'
echo "All tests passed against the ${container_type:?} container ${container_name:?} ..."
