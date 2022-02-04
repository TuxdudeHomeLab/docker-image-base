#!/usr/bin/env bash

set -x -e -o pipefail

script_name="$(basename "$(realpath "${BASH_SOURCE[0]}")")"
script_parent_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
script_abs_path="${script_parent_dir:?}/${script_name:?}"

base_install_dir="/opt"

init() {
    mkdir -p ${base_install_dir:?}/bin
    ln -sf ${script_abs_path:?} ${base_install_dir:?}/bin/homelab
}

destroy() {
    rm -f ${base_install_dir:?}/bin/homelab
    rm -f ${script_abs_path}
}

update_repo() {
    # Refresh package list from the repository.
    DEBIAN_FRONTEND=noninteractive apt-get update
}

cleanup_post_package_op() {
    # Remove any packages that are no longer required.
    DEBIAN_FRONTEND=noninteractive apt-get autoremove --assume-yes
    DEBIAN_FRONTEND=noninteractive apt-get clean
}

install_packages() {
    DEBIAN_FRONTEND=noninteractive apt-get install \
        --assume-yes \
        --no-install-recommends \
        ${@}
}

remove_packages() {
    DEBIAN_FRONTEND=noninteractive apt-get remove \
        --assume-yes \
        --purge \
        --allow-remove-essential \
        ${@}
}

cleanup_post_package_op() {
    # Manually remove leftover cruft after having to run
    # an apt command.
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /var/cache/debconf/* \
        /var/cache/apt/archives \
        /var/cache/ldconfig/aux-cache \
        /var/log/apt/* \
        /var/log/*log \
        /usr/share/doc/* \
        /usr/share/doc-base/* \
        /usr/share/gcc/* \
        /usr/share/gdb/* \
        /usr/share/info/* \
        /usr/share/man/* \
        /usr/share/pixmaps*
}

configure_en_us_utf8_locale() {
    # Set up en_US.UTF-8 locale.
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    dpkg-reconfigure --frontend=noninteractive locales
    update-locale LANG=en_US.UTF-8
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8
    # Remove other locale files which we won't use.
    find /usr/share/i18n/locales ! -name en_US -type f -exec rm -v {} +
    find /usr/share/i18n/charmaps ! -name UTF-8.gz -type f -exec rm -v {} +
}

purge_locales() {
    # Purge existing locales.
    DEBIAN_FRONTEND=noninteractive apt-get purge locales
}

setup_apt() {
    # Do not install recommended and suggested packages.
    echo 'APT::Install-Recommends "0" ; APT::Install-Suggests "0" ;' > \
        /etc/apt/apt.conf.d/01-no-recommended
    # Do not install these files as part of package installations.
    echo 'path-exclude=/usr/share/doc/*' > \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
    echo 'path-exclude=/usr/share/groff/*' >> \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
    echo 'path-exclude=/usr/share/info/*' >> \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
    echo 'path-exclude=/usr/share/linda/*' >> \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
    echo 'path-exclude=/usr/share/lintian/*' >> \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
    echo 'path-exclude=/usr/share/man/*' >> \
        /etc/dpkg/dpkg.cfg.d/path_exclusions
}

remove_machine_id() {
    # Debian rootfs contains a static machine-id file and we don't want to
    # use that. Instead clear the machine ID to a 0-byte file.
    rm /etc/machine-id
    touch /etc/machine-id
}

add_user() {
    local user_name=${1:?}
    local user_id=${2:?}
    local group_name=${3:?}
    local group_id=${4:?}
    local create_home_dir=""
    if [[ "$5" == "--create-home-dir" ]]; then
        create_home_dir="--create-home "
    fi
    groupadd --gid ${group_id:?} ${group_name:?}
    useradd \
        ${create_home_dir:?} \
        --shell /bin/bash \
        --uid ${user_id:?} \
        --gid ${group_id:?} \
        ${user_name:?}
}

install_tar_dist() {
    local download_url="${1:?}"
    local download_checksum="${2:?}"
    local package_name="${3:?}"
    local symlink_to="${4:?}"
    local owner_user="${5:?}"
    local owner_group="${6:?}"
    local install_dir="${base_install_dir:?}/${package_name:?}"
    local tar_file="/tmp/file-$(date +'%Y-%m-%d_%H-%M-%S.%3N')"

    # Prepare the install directory.
    rm -rf ${install_dir:?}
    mkdir -p ${base_install_dir:?}
    pushd ${base_install_dir:?} >/dev/null

    # Download and unpack the release.
    curl --silent --location --output ${tar_file:?} ${download_url:?}
    echo "${download_checksum:?} ${tar_file:?}" | sha256sum -c
    tar xf ${tar_file:?}
    rm ${tar_file:?}

    # Set up symlinks.
    ln -s ${symlink_to:?} ${package_name:?}

    # Make the installed directory owned by the specified user and the group.
    chown -R ${owner_user:?}:${owner_group:?} ${install_dir:?}

    popd >/dev/null
}

case "$1" in
    "setup")
        init
        setup_apt
        remove_machine_id
        update_repo
        purge_locales
        cleanup_post_package_op
        ;;
    "destroy")
        destroy
        ;;
    "cleanup")
        cleanup_post_package_op
        ;;
    "install")
        update_repo
        install_packages "${@:2}"
        cleanup_post_package_op
        ;;
    "remove")
        update_repo
        remove_packages "${@:2}"
        cleanup_post_package_op
        ;;
    "setup-en-us-utf8-locale")
        configure_en_us_utf8_locale
        ;;
    "add-user")
        add_user "${@:2}"
        ;;
    "install-tar-dist")
        install_tar_dist "${@:2}"
        ;;
    *)
        echo "Invalid command \"$1\""
        exit 1
esac
