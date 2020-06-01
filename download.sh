#!/usr/bin/env bash

mkdir -p ./rootfs
curl -skLo ./rootfs/alpine-minirootfs-3.11.3-armhf.tar.gz http://dl-cdn.alpinelinux.org/alpine/v3.11/releases/armhf/alpine-minirootfs-3.11.3-armhf.tar.gz
curl -skLo ./rootfs/alpine-minirootfs-3.11.3-x86_64.tar.gz http://dl-cdn.alpinelinux.org/alpine/v3.11/releases/x86_64/alpine-minirootfs-3.11.3-x86_64.tar.gz
