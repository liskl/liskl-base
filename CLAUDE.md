# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker base image project that creates minimal Alpine Linux containers. The project builds base Docker images using Alpine Linux minirootfs tarballs for multiple architectures, providing complete parity with official Alpine Linux Docker images.

## Architecture

- **Dockerfile**: Creates a minimal Alpine Linux base image from scratch using minirootfs tarballs
- **download.sh**: Downloads Alpine Linux minirootfs archives for all supported architectures 
- **rootfs/**: Contains Alpine Linux minirootfs tarballs (versions 3.14.3 through 3.22.1 for all architectures)
- **GitHub Actions**: Automated CI/CD workflows for building and publishing Docker images

## Key Files

### Core Build Files
- `Dockerfile`: Multi-architecture Alpine base image build (FROM scratch, uses minirootfs tarballs)
- `download.sh`: Downloads Alpine minirootfs archives for all architectures
- `build-local.sh`: Local testing script with multi-arch and emulation testing
- `test-build.sh`: Quick interactive Docker image testing script

### CI/CD Workflows
- `.github/workflows/on-push-master_build-push.yaml`: Master branch workflow (builds all Alpine versions)
- `.github/workflows/on-push-non-master_build-push.yaml`: Feature branch workflow (builds with commit SHA tags)
- `.github/actions/docker/`: Custom Docker action for multi-arch builds with QEMU emulation

### Rootfs Archives
- `rootfs/alpine-minirootfs-{version}-{arch}.tar.gz`: Alpine Linux minirootfs tarballs
  - Versions: 3.14.3, 3.15.11, 3.16.9, 3.17.10, 3.18.12, 3.19.8, 3.20.7, 3.21.4, 3.22.1
  - Architectures: x86, x86_64, armv7, armhf, aarch64, ppc64le, s390x (3.20+ includes riscv64)

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

### Local Testing
```bash
# Quick interactive testing
./test-build.sh

# Build specific architecture for testing
./build-local.sh -a amd64                    # Build AMD64 only
./build-local.sh -a arm64                    # Build ARM64 only
./build-local.sh -v 3.21.4 -a amd64        # Specific Alpine version

# Build all architectures
./build-local.sh -A                         # Build all Alpine versions

# Push to registry for testing
./build-local.sh -p -r myregistry/alpine    # Push to custom registry
```

## CI/CD Workflows

The project uses GitHub Actions with two workflows:

1. **Master Branch** (on-push-master_build-push.yaml): Builds and pushes multi-architecture images for all Alpine versions
2. **Feature Branches** (on-push-non-master_build-push.yaml): Builds and pushes development images tagged with commit SHA

Both workflows publish to Docker Hub with full multi-architecture support.

## Build Arguments

### Dockerfile Arguments (Dockerfile:5-12)
- `RELEASE_VERSION`: Alpine version or commit SHA (set by CI, default: unknown)
- `BRANCH`: Git branch name or commit SHA (set by CI, default: unknown)  
- `alpine_version`: Alpine Linux version (default: 3.22.1)
- `ALPINE_ARCH`: Target Alpine architecture name (passed from build system)

### build-local.sh Options (build-local.sh:25-49)
- `-v, --version VERSION`: Alpine version to build (default: 3.22.1)
- `-a, --arch ARCH`: Build single architecture only (amd64, arm64, etc.)
- `-A, --all-versions`: Build all supported Alpine versions
- `-p, --push`: Push images to registry after building
- `-e, --test-emulation`: Test Docker Desktop architecture emulation capabilities
- `-r, --registry PREFIX`: Registry prefix (default: liskl/base)

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
- Minimal container optimized for size and security

## Required GitHub Configuration

#### GitHub Secrets (Private) - Required for CI/CD workflows
- **DOCKERHUB_USERNAME**: Docker Hub username for image publishing (.github/workflows/*:25)
- **DOCKERHUB_TOKEN**: Docker Hub access token for authentication (.github/workflows/*:26)

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

## Branch Namespacing Guidelines

- Ensure consistent branch naming using namespaces aligned with commitlint prefixes:
  - `docs/<name>`: For documentation-related branches
  - `feat/<name>`: For new feature development
  - `chore/<name>`: For maintenance and housekeeping tasks
  - `fix/<name>`: For bug fixes and patches

## File Reference Quick Guide

### When working with builds:
- Main build file: `Dockerfile` (lines 1-25, FROM scratch Alpine build)
- Local testing: `build-local.sh` (comprehensive build script with multi-arch support)
- Quick testing: `test-build.sh` (simple interactive testing)
- Download Alpine archives: `download.sh`

### When working with CI/CD:
- Master workflow: `.github/workflows/on-push-master_build-push.yaml` (builds all Alpine versions)
- Feature workflow: `.github/workflows/on-push-non-master_build-push.yaml` (commit SHA tags)
- Custom action: `.github/actions/docker/` (multi-arch with QEMU)

### When checking Alpine versions/architectures:
- Available versions: 3.14.3, 3.15.11, 3.16.9, 3.17.10, 3.18.12, 3.19.8, 3.20.7, 3.21.4, 3.22.1
- Base architectures (all versions): x86, x86_64, armv7, armhf, aarch64, ppc64le, s390x
- Conditional architecture: riscv64 (Alpine 3.20+ only)
- Archive location: `rootfs/alpine-minirootfs-{version}-{arch}.tar.gz`