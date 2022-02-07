#!/usr/bin/env bash

set -x -e -o pipefail

export DEBIAN_FRONTEND=noninteractive

# These variables are set here directly to allow the child
# images to directly invoke these commands without a dependency
# on the right environment variables (and/or Docker args) to
# be set in the child images.
S6_OVERLAY_VERSION=3.0.0.2
S6_OVERLAY_CHECKSUM_NOARCH=17880e4bfaf6499cd1804ac3a6e245fd62bc2234deadf8ff4262f4e01e3ee521
S6_OVERLAY_CHECKSUM_X86_64=a4c039d1515812ac266c24fe3fe3c00c48e3401563f7f11d09ac8e8b4c2d0b0c
S6_OVERLAY_CHECKSUM_AARCH64=e6c15e22dde00af4912d1f237392ac43a1777633b9639e003ba3b78f2d30eb33
S6_OVERLAY_CHECKSUM_ARMHF=49cc67181fb38c010c31ff1ff1ff63ec9046f2520d8168e0c9d59046ef6a6bfe
# TODO: use lsb_release -sc or equivalent.
DEBIAN_RELEASE="bullseye"

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
    apt-get update
}

install_packages() {
    apt-get install \
        --assume-yes \
        --no-install-recommends \
        ${@}
}

remove_packages() {
    apt-get remove \
        --assume-yes \
        --purge \
        --allow-remove-essential \
        ${@}
}

cleanup_post_package_op() {
    # Remove any packages that are no longer required.
    apt-get remove --purge --auto-remove -y
    apt-get autoremove --assume-yes
    apt-get clean
    apt-get purge -y --auto-remove
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
    apt-get purge locales
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
        ${create_home_dir} \
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
    tar -xf ${tar_file:?}
    rm ${tar_file:?}

    # Set up symlinks.
    ln -s ${symlink_to:?} ${package_name:?}

    # Make the installed directory owned by the specified user and the group.
    chown -R ${owner_user:?}:${owner_group:?} ${install_dir:?}

    popd >/dev/null
}

install_git_repo() {
    local git_repo_url="${1:?}"
    local git_branch_or_tag="${2:?}"
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

    # Clone the git repository.
    git clone --depth 1 --branch ${git_branch_or_tag:?} ${git_repo_url:?} ${symlink_to:?}

    # Set up symlinks.
    ln -s ${symlink_to:?} ${package_name:?}

    # Make the installed directory owned by the specified user and the group.
    chown -R ${owner_user:?}:${owner_group:?} ${install_dir:?}

    popd >/dev/null
}

# Docker platform to uname arch mapping
# "linux/amd64"     "amd64"
# "linux/386"       "x86"
# "linux/arm64"     "aarch64"
# "linux/arm64/v8"  "aarch64"
# "linux/arm/v7"    "armhf", "armv7"
# "linux/arm/v6"    "arm"
# "linux/ppc64le"   "ppc64le"
download_and_install_s6() {
    local "platform=${1:?}"
    local tar_file="/tmp/file-$(date +'%Y-%m-%d_%H-%M-%S.%3N')"
    local download_url="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION:?}/s6-overlay-${platform:?}-${S6_OVERLAY_VERSION:?}.tar.xz"
    checksum_var_name="S6_OVERLAY_CHECKSUM_${platform^^}"
    local download_checksum="${!checksum_var_name}"

    echo "Downloading s6-overlay for \"${platform:?}\" v${S6_OVERLAY_VERSION:?}"
    curl --silent --location --output ${tar_file:?} ${download_url:?}
    echo "${download_checksum:?} ${tar_file:?}" | sha256sum -c
    tar -xpf ${tar_file:?} -C /
    rm ${tar_file:?}
}

install_s6() {
    local platform="$(uname -m)"
    if [[ "${platform:?}" == "armv7l" ]]; then
        platform="armhf"
    fi
    download_and_install_s6 noarch
    download_and_install_s6 "${platform:?}"
}

install_pkg_gpg_key() {
    gpg_key="${1:?}"
    keyserver="hkp://keyserver.ubuntu.com:80"
    homelab install gnupg1

    echo "Fetching GPG key $gpg_key from $keyserver"
    apt-key adv \
        --keyserver "$keyserver" \
        --keyserver-options timeout=10 \
        --recv-keys "${gpg_key:?}"
    apt-get remove --purge --auto-remove -y gnupg1
}

random_file_name() {
    shuf -zer -n10  {A..Z} {a..z} {0..9} | tr -d '\0'
}

# Build from sources, package them as a .deb and install the .deb packages.
install_pkg_from_deb_src() {
    src_repo="${1:?}"
    pkgs="${2:?}"
    apt_repo_base_path="/etc/apt/sources.list.d"
    src_repo_file="${apt_repo_base_path:?}/src_$(random_file_name).list"
    bin_repo_file="${apt_repo_base_path:?}/bin_$(random_file_name).list"
    bin_repo_dir="$(mktemp -d)"

    echo "${src_repo:?}" > ${src_repo_file:?}

    # Ensure APT's "_apt" user can access the files.
    chmod 777 "${bin_repo_dir:?}"
    # Save the list of currently-installed packages so build dependencies
    # can be cleanly removed later.
    saved_apt_mark="$(apt-mark showmanual)"

    # Download the build dependencies.
    # Among the build dependencies, some packages depend on utilities
    # like getopt part of util-linux.
    update_repo
    install_packages util-linux
    apt-get build-dep -y ${pkgs:?}

    # Compile the target packages.
    pushd "${bin_repo_dir:?}"
    DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" apt-get source --compile ${pkgs:?}
    popd

    # Remove the source repository as it is no longer needed.
    rm ${src_repo_file:?}

    # Reset apt-mark's "manual" list so that "purge --auto-remove" will
    # remove all the build dependencies. The purge is done as a last step.
    apt-mark showmanual | xargs apt-mark auto > /dev/null
    [ -z "$saved_apt_mark" ] || apt-mark manual $saved_apt_mark;

    # Create a temporary local APT repo to install from and dependency
    # resolution will be handled by apt.
    ls -lAFh "${bin_repo_dir:?}"
    pushd "${bin_repo_dir:?}"
    dpkg-scanpackages . > Packages
    popd
    grep '^Package: ' "${bin_repo_dir:?}/Packages"
    echo "deb [ trusted=yes ] file://${bin_repo_dir:?} ./" > ${bin_repo_file:?}

    # Work around the following APT issue by using "Acquire::GzipIndexes=false"
    # (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
    #   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
    #   ...
    #   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
    apt-get -o Acquire::GzipIndexes=false update

    # Install the target packages, which will use the .deb packages that we
    # just built and published to the local repository.
    install_packages ${pkgs:?}

    # Remove the build artifacts and the binary repository.
    remove_packages util-linux
    rm -rf "${bin_repo_dir:?}" ${bin_repo_file:?}
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
    "install-s6")
        install_s6
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
    "install-git-repo")
        install_git_repo "${@:2}"
        ;;
    "install-pkg-gpg-key")
        install_pkg_gpg_key "${@:2}"
        cleanup_post_package_op
        ;;
    "install-pkg-from-deb-src")
        install_pkg_from_deb_src "${@:2}"
        cleanup_post_package_op
        ;;
    *)
        echo "Invalid command \"$1\""
        exit 1
esac
