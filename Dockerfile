ARG UPSTREAM_IMAGE_NAME
ARG UPSTREAM_IMAGE_TAG
FROM ${UPSTREAM_IMAGE_NAME}:${UPSTREAM_IMAGE_TAG} as rootfs

SHELL ["/bin/bash", "-c"]
ENV PATH="/opt/bin:${PATH}"

COPY scripts/homelab.sh /opt/homelab/

ARG PACKAGES_TO_INSTALL
ARG PACKAGES_TO_REMOVE

RUN \
    set -e -o pipefail \
    # Setup the homelab utility. \
    && /opt/homelab/homelab.sh setup \
    && ls -l /opt/bin/ /opt/homelab/ \
    # Install packages which will help with debugging. \
    && homelab install ${PACKAGES_TO_INSTALL:?} \
    # Set up en_US.UTF-8 locale \.
    # locale package is part of PACKAGES_TO_INSTALL. \
    && homelab setup-en-us-utf8-locale \
    # Remove packages that will never be used. \
    && homelab remove ${PACKAGES_TO_REMOVE:?}

# Flatten the layers to reduce the final image size.
FROM scratch
COPY --from=rootfs / /

SHELL ["/bin/bash", "-c"]
ENV PATH="/opt/bin:${PATH}"
CMD ["bash"]
