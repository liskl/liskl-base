FROM scratch

MAINTAINER loren.lisk@liskl.com

ARG RELEASE_VERSION=unknown
ARG BRANCH=unknown
ARG alpine_version=3.22.1
ARG ALPINE_ARCH

ENV COMMIT_SHA=$RELEASE_VERSION
ENV BRANCH=$BRANCH

ADD ./rootfs/alpine-minirootfs-${alpine_version}-${ALPINE_ARCH}.tar.gz /

RUN echo -ne "BASE_BRANCH=$BRANCH\nBASE_SHA=$COMMIT_SHA\nALPINE_VERSION=${alpine_version}\nARCH=${ALPINE_ARCH}\n" > /etc/build_release

ENTRYPOINT ["/bin/sh"]
