#!/usr/bin/env bash

mkdir -p ./rootfs

# Alpine Linux minirootfs downloads for versions 3.14.3 through 3.22.1
versions=(
    "3.14.3"
    "3.15.11" 
    "3.16.9"
    "3.17.10"
    "3.18.12"
    "3.19.8"
    "3.20.7"
    "3.21.4"
    "3.22.1"
)

for version in "${versions[@]}"; do
    major_minor=$(echo $version | cut -d. -f1,2)
    echo "Downloading Alpine $version..."
    curl -skLo "./rootfs/alpine-minirootfs-${version}-armhf.tar.gz" "https://dl-cdn.alpinelinux.org/alpine/v${major_minor}/releases/armhf/alpine-minirootfs-${version}-armhf.tar.gz"
    curl -skLo "./rootfs/alpine-minirootfs-${version}-x86_64.tar.gz" "https://dl-cdn.alpinelinux.org/alpine/v${major_minor}/releases/x86_64/alpine-minirootfs-${version}-x86_64.tar.gz"
done
