FROM scratch

MAINTAINER loren.lisk@liskl.com

ARG COMMIT_SHA=unknown
ARG VERSION=v0.0.0

ENV COMMIT_SHA=$COMMIT_SHA
ENV VERSION=$VERSION

ENV alpine_version 3.10.3
ENV ARCH x86_64

ADD ./rootfs/alpine-minirootfs-${alpine_version}-${ARCH}.tar.gz /

ENTRYPOINT ["/bin/sh"]
