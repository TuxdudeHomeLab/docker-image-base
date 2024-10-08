# syntax=docker/dockerfile:1

ARG UPSTREAM_IMAGE_NAME
ARG UPSTREAM_IMAGE_TAG
FROM ${UPSTREAM_IMAGE_NAME}:${UPSTREAM_IMAGE_TAG} as rootfs

SHELL ["/bin/bash", "-c"]
ENV PATH="/opt/bin:${PATH}"

COPY scripts /opt/homelab/scripts

ARG PACKAGES_TO_INSTALL
ARG PACKAGES_TO_REMOVE

RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Setup the homelab utility along with installing \
    # packages which will help with debugging. \
    && /opt/homelab/scripts/homelab.sh setup ${PACKAGES_TO_INSTALL:? } \
    # Set up en_US.UTF-8 locale \.
    # locale package is part of PACKAGES_TO_INSTALL. \
    && homelab setup-en-us-utf8-locale \
    # Remove packages that will never be used. \
    && homelab remove ${PACKAGES_TO_REMOVE:?}

# Flatten the layers to reduce the final image size.
FROM scratch
COPY --from=rootfs / /

# hadolint ignore=DL3002
USER root
ENV PATH="/opt/bin:${PATH}"

SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["picoinit"]
CMD ["bash"]
STOPSIGNAL SIGHUP
