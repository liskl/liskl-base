# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker base image project that creates minimal Alpine Linux containers. The project builds base Docker images using Alpine Linux minirootfs tarballs for multiple architectures, providing complete parity with official Alpine Linux Docker images.

## Architecture

- **Dockerfile**: Creates a minimal Alpine Linux base image from scratch using minirootfs tarballs
- **download.sh**: Downloads Alpine Linux minirootfs archives for all supported architectures 
- **rootfs/**: Contains Alpine Linux minirootfs tarballs (versions 3.14.3 through 3.22.1 for all architectures)
- **GitHub Actions**: Automated CI/CD workflows for building and publishing Docker images

## Build Commands

### Docker Image Building
```bash
# Build the Docker image locally (default: Alpine 3.22.1)
docker build -t liskl/base .

# Build with specific Alpine version and architecture
docker build --build-arg alpine_version=3.22.1 --build-arg ALPINE_ARCH=x86_64 -t liskl/base:alpine-3.22.1 .

# Build for different architectures
docker build --build-arg ALPINE_ARCH=aarch64 -t liskl/base:arm64 .
docker build --build-arg ALPINE_ARCH=armhf -t liskl/base:armv7 .

# Multi-platform build using buildx
docker buildx build --platform linux/amd64,linux/arm64/v8 --build-arg alpine_version=3.22.1 -t liskl/base:alpine-3.22.1 .
```

### Download Alpine Rootfs
```bash
# Download required Alpine minirootfs archives
./download.sh
```

## CI/CD Workflows

The project uses GitHub Actions with two workflows:

1. **Master Branch** (on-push-master_build-push.yaml): Builds and pushes multi-architecture images for all Alpine versions
2. **Feature Branches** (on-push-non-master_build-push.yaml): Builds and pushes development images tagged with commit SHA

Both workflows publish to Docker Hub with full multi-architecture support.

## Build Arguments

- `RELEASE_VERSION`: Alpine version or commit SHA (set by CI)
- `BRANCH`: Git branch name or commit SHA (set by CI)  
- `alpine_version`: Alpine Linux version (default: 3.22.1)
- `ALPINE_ARCH`: Target Alpine architecture name

### Supported Architectures

**Base architectures** (available for all Alpine versions 3.14.3+):
- `x86` (linux/386)
- `x86_64` (linux/amd64)
- `armv7` (linux/arm/v6)
- `armhf` (linux/arm/v7)
- `aarch64` (linux/arm64/v8)
- `ppc64le` (linux/ppc64le)
- `s390x` (linux/s390x)

**Conditional architectures**:
- `riscv64` (linux/riscv64) - Available for Alpine 3.20+ only

## Image Details

The resulting Docker image:
- Built FROM scratch for minimal size
- Uses Alpine Linux minirootfs as base layer
- Sets environment variables for build tracking
- Default entrypoint: `/bin/sh`
- Includes build metadata in `/etc/build_release`
- Enhanced with SBOM generation and security attestations

## Security Features

### SBOM Generation (Implemented)
- **SPDX format**: Industry-standard SBOM format for compliance
- **CycloneDX format**: Enhanced tool compatibility and ecosystem support  
- **Automated generation**: Generated for every image during CI/CD builds
- **Cosign attestation**: Cryptographically signed and attached to images
- **Multi-architecture coverage**: SBOMs for all supported platforms
- **Vulnerability ready**: Compatible with grype, snyk, and other scanners

### Security Verification
```bash
# Verify SBOM attestations
cosign verify-attestation --type spdx liskl/base:alpine-3.22.1
cosign verify-attestation --type cyclonedx liskl/base:alpine-3.22.1

# Extract SBOM for vulnerability scanning
cosign verify-attestation --type spdx liskl/base:alpine-3.22.1 \
  | jq -r '.payload | @base64d | fromjson | .predicate' > sbom.spdx.json

# Run vulnerability scan
grype sbom:sbom.spdx.json --fail-on critical

# Use verification script
./scripts/verify-sbom.sh alpine-3.22.1
```

## Commit Message Format

This project uses commitlint-compatible commit messages. Follow the conventional commits specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependencies, etc.
- `ci`: CI/CD configuration changes

### Examples
```
feat: add support for Alpine 3.15
fix: correct armhf build argument handling
docs: update README with new build instructions
ci: migrate workflows to Docker Hub
```