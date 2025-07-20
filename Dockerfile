FROM scratch

MAINTAINER loren.lisk@liskl.com

ARG RELEASE_VERSION=unknown
ARG BRANCH=unknown
ARG alpine_version=3.22.1
# ALPINE_ARCH: Alpine architecture name passed from build system
# Supported values: x86, x86_64, armv7, armhf, aarch64, ppc64le, s390x, riscv64
# Maps from Docker platforms: linux/386, linux/amd64, linux/arm/v6, linux/arm/v7, 
#                            linux/arm64/v8, linux/ppc64le, linux/s390x, linux/riscv64
ARG ALPINE_ARCH

ENV COMMIT_SHA=$RELEASE_VERSION
ENV BRANCH=$BRANCH

ADD ./rootfs/alpine-minirootfs-${alpine_version}-${ALPINE_ARCH}.tar.gz /

RUN printf "BASE_BRANCH=%s\nBASE_SHA=%s\nALPINE_VERSION=%s\nARCH=%s\n" "${BRANCH}" "${COMMIT_SHA}" "${alpine_version}" "${ALPINE_ARCH}" > /etc/build_release

ENTRYPOINT ["/bin/sh"]
