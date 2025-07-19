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

# Core architectures supported by all Alpine Linux versions
base_architectures=(
    "x86"        # linux/386
    "x86_64"     # linux/amd64
    "armv7"      # linux/arm/v6
    "armhf"      # linux/arm/v7
    "aarch64"    # linux/arm64/v8
    "ppc64le"    # linux/ppc64le
    "s390x"      # linux/s390x
)

# Additional architectures available from specific versions
riscv64_architectures=(
    "riscv64"    # linux/riscv64 (available from Alpine 3.20+)
)

for version in "${versions[@]}"; do
    major_minor=$(echo $version | cut -d. -f1,2)
    minor_version=$(echo $version | cut -d. -f2)
    echo "Downloading Alpine $version for all architectures..."
    
    # Download base architectures for all versions
    for arch in "${base_architectures[@]}"; do
        echo "  - $arch"
        curl -skLo "./rootfs/alpine-minirootfs-${version}-${arch}.tar.gz" \
            "https://dl-cdn.alpinelinux.org/alpine/v${major_minor}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz"
    done
    
    # Download riscv64 only for Alpine 3.20+
    if [[ $minor_version -ge 20 ]]; then
        for arch in "${riscv64_architectures[@]}"; do
            echo "  - $arch (3.20+ only)"
            curl -skLo "./rootfs/alpine-minirootfs-${version}-${arch}.tar.gz" \
                "https://dl-cdn.alpinelinux.org/alpine/v${major_minor}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz"
        done
    fi
    echo ""
done

# Calculate total files (base archs for all versions + riscv64 for 3.20+ only)
versions_with_riscv64=0
for version in "${versions[@]}"; do
    minor_version=$(echo $version | cut -d. -f2)
    if [[ $minor_version -ge 20 ]]; then
        ((versions_with_riscv64++))
    fi
done

total_files=$((${#versions[@]} * ${#base_architectures[@]} + versions_with_riscv64 * ${#riscv64_architectures[@]}))
echo "Download complete! Total files: $total_files"
