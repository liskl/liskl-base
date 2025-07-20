# Temporary stage to copy the right Alpine rootfs
FROM alpine:3.22.1 AS rootfs_extractor

ARG RELEASE_VERSION=unknown
ARG BRANCH=unknown  
ARG alpine_version=3.22.1

# Docker platform detection - automatically set by BuildKit for multi-platform builds
ARG TARGETARCH
ARG TARGETVARIANT

# ALPINE_ARCH can be explicitly set or auto-detected from TARGETARCH
ARG ALPINE_ARCH

# Copy our rootfs files and extraction script
COPY ./rootfs ./rootfs
COPY ./copy-rootfs.sh ./copy-rootfs.sh

# Create directory for extracted rootfs and run extraction
RUN mkdir -p /extracted_rootfs && \
    cd /extracted_rootfs && \
    # Detect Alpine architecture from Docker TARGETARCH if ALPINE_ARCH not set
    if [ -z "${ALPINE_ARCH}" ]; then \
        case "${TARGETARCH}${TARGETVARIANT}" in \
            "386") ALPINE_ARCH="x86" ;; \
            "amd64") ALPINE_ARCH="x86_64" ;; \
            "armv6") ALPINE_ARCH="armv7" ;; \
            "armv7") ALPINE_ARCH="armhf" ;; \
            "arm64") ALPINE_ARCH="aarch64" ;; \
            "ppc64le") ALPINE_ARCH="ppc64le" ;; \
            "s390x") ALPINE_ARCH="s390x" ;; \
            "riscv64") ALPINE_ARCH="riscv64" ;; \
            *) echo "Error: Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}" >&2; exit 1 ;; \
        esac; \
    fi && \
    ROOTFS_FILE="../rootfs/alpine-minirootfs-${alpine_version}-${ALPINE_ARCH}.tar.gz" && \
    echo "Building for architecture: ${ALPINE_ARCH}" && \
    echo "Using rootfs file: ${ROOTFS_FILE}" && \
    if [ ! -f "${ROOTFS_FILE}" ]; then \
        echo "Error: Rootfs file not found: ${ROOTFS_FILE}" >&2; \
        echo "Available files:" >&2; \
        ls -la ../rootfs/alpine-minirootfs-${alpine_version}-*.tar.gz >&2 || echo "No files found" >&2; \
        exit 1; \
    fi && \
    tar -xzf "${ROOTFS_FILE}" && \
    echo "Rootfs extracted successfully for ${ALPINE_ARCH}"

# Final stage - build from scratch using extracted rootfs
FROM scratch

LABEL maintainer="loren.lisk@liskl.com"

ARG RELEASE_VERSION=unknown
ARG BRANCH=unknown
ARG alpine_version=3.22.1
ARG TARGETARCH
ARG TARGETVARIANT
ARG ALPINE_ARCH

ENV COMMIT_SHA=$RELEASE_VERSION
ENV BRANCH=$BRANCH

# Copy the extracted Alpine rootfs from the previous stage
COPY --from=rootfs_extractor /extracted_rootfs/ /

RUN set -e && \
    if [ -z "${ALPINE_ARCH}" ]; then \
        case "${TARGETARCH}${TARGETVARIANT}" in \
            "386") DETECTED_ALPINE_ARCH="x86" ;; \
            "amd64") DETECTED_ALPINE_ARCH="x86_64" ;; \
            "armv6") DETECTED_ALPINE_ARCH="armv7" ;; \
            "armv7") DETECTED_ALPINE_ARCH="armhf" ;; \
            "arm64") DETECTED_ALPINE_ARCH="aarch64" ;; \
            "ppc64le") DETECTED_ALPINE_ARCH="ppc64le" ;; \
            "s390x") DETECTED_ALPINE_ARCH="s390x" ;; \
            "riscv64") DETECTED_ALPINE_ARCH="riscv64" ;; \
            *) DETECTED_ALPINE_ARCH="unknown" ;; \
        esac; \
    else \
        DETECTED_ALPINE_ARCH="${ALPINE_ARCH}"; \
    fi && \
    echo "BASE_BRANCH=${BRANCH}" > /etc/build_release && \
    echo "BASE_SHA=${COMMIT_SHA}" >> /etc/build_release && \
    echo "ALPINE_VERSION=${alpine_version}" >> /etc/build_release && \
    echo "ARCH=${DETECTED_ALPINE_ARCH}" >> /etc/build_release

ENTRYPOINT ["/bin/sh"]
