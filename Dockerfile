FROM scratch

MAINTAINER loren.lisk@liskl.com

ARG RELEASE_VERSION=unknown
ARG BRANCH=unknown
ARG alpine_version=3.22.1
ARG TARGETARCH

ENV COMMIT_SHA=$RELEASE_VERSION
ENV BRANCH=$BRANCH

# Map Docker platform to Alpine architecture
ENV ARCH=${TARGETARCH}

ADD ./rootfs/alpine-minirootfs-${alpine_version}-${ARCH}.tar.gz /

RUN echo -ne "BASE_BRANCH=$BRANCH\nBASE_SHA=$COMMIT_SHA\nALPINE_VERSION=${alpine_version}\nARCH=${ARCH}\n" > /etc/build_release

ENTRYPOINT ["/bin/sh"]
