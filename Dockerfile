FROM scratch

MAINTAINER loren.lisk@liskl.com 

ENV alpine_version 3.10.3
ENV ARCH x86_64

ADD ./rootfs/alpine-minirootfs-${alpine_version}-${ARCH}.tar.gz /

ENTRYPOINT ["/bin/sh"]
