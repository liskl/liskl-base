#!/usr/bin/env bash

mkdir -p ./rootfs
curl -skLo ./rootfs/alpine-minirootfs-3.10.3-armhf.tar.gz http://dl-cdn.alpinelinux.org/alpine/v3.10/releases/armhf/alpine-minirootfs-3.10.3-armhf.tar.gz
curl -skLo ./rootfs/alpine-minirootfs-3.10.3-x86_64.tar.gz http://dl-cdn.alpinelinux.org/alpine/v3.10/releases/x86_64/alpine-minirootfs-3.10.3-x86_64.tar.gz

