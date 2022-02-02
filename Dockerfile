ARG IMAGE_NAME=debian
ARG IMAGE_LABEL=bullseye-20220125-slim
ARG DEBIAN_FRONTEND=noninteractive

FROM $IMAGE_NAME:$IMAGE_LABEL as start

# List of essential programs for the base debian system and/or for
# debian's package management, and hence can't be removed:
# apt
# base-files
# base-passwd
# coreutils
# dash
# debconf
# debian-archive-keyring
# debianutils
# diffutils
# findutils
# dpkg
# gcc-10-base
# gpgv
# grep
# gzip
# hostname
# init-system-helpers
# mawk
# lsb-base
# mount
# perl-base
# sed
# tar
# tzdata
# zlib1g

# List of essential programs to get a slightly better shell/tty:
# ncurses-base

# List of essential programs needed only while creating the image,
# but not running it:
# adduser
# login
# passwd

RUN \
    echo 'APT::Install-Recommends "0" ; APT::Install-Suggests "0" ;' > /etc/apt/apt.conf.d/01-no-recommended \
    # Do not install these files as part of package installations. \
    && echo 'path-exclude=/usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/path_exclusions \
    && echo 'path-exclude=/usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/path_exclusions \
    && echo 'path-exclude=/usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/path_exclusions \
    && echo 'path-exclude=/usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/path_exclusions \
    && echo 'path-exclude=/usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/path_exclusions \
    && echo 'path-exclude=/usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/path_exclusions \
    # Refresh package list from the repository. \
    && apt-get update \
    # # Set up en_US.UTF-8 locale. \
    && apt-get purge locales \
    && apt-get install --assume-yes --no-install-recommends locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8 \
    && echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8 \
    # Remove other locale files which we won't use. \
    && find /usr/share/i18n/locales ! -name en_US -type f -exec rm -v {} + \
    && find /usr/share/i18n/charmaps ! -name UTF-8.gz -type f -exec rm -v {} + \
    # Install packages which will help with debugging. \
    && apt-get install --assume-yes --no-install-recommends \
        bash \
        curl \
        dnsutils \
        grep \
        gzip \
        iputils-ping \
        iproute2 \
        locales \
        net-tools \
        procps \
        sed \
        tar \
        tzdata \
        wget \
    # Remove packages that will never be used. \
    && apt-get remove --assume-yes --purge --allow-remove-essential \
        bsdutils \
        e2fsprogs \
        gcc-9-base \
        libext2fs2 \
        libss2 \
        logsave \
        ncurses-bin \
        sysvinit-utils \
        util-linux \
    # Remove any packages that are no longer required. \
    && apt-get autoremove --assume-yes \
    && apt-get clean \
    # Debian rootfs contains a static machine-id file and we don't want to \
    # use that. Instead clear the machine ID to a 0-byte file. \
    && rm /etc/machine-id && touch /etc/machine-id \
    # Manually remove leftover cruft. \
    && rm -rf \
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

# Flatten the layers to reduce the final image size.
FROM scratch
COPY --from=start / /
CMD ["bash"]
