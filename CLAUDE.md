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

### Scripts
- `scripts/check-immutable-tags.sh`: Immutable Docker tag detection script (prevents pushing to protected tags)
- `scripts/test-check-immutable-tags.sh`: Unit tests for immutable tag detection

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

# Build all architectures with attestation testing
./build-local.sh -t                         # Test BuildKit attestations
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
- `-t, --test-attestations`: Test BuildKit attestation verification after build
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
- Enhanced with BuildKit native SBOM generation and build attestations
- Minimal container optimized for size and security

## Security Features

### BuildKit Native Attestations (Implemented)
The project leverages Docker BuildKit's built-in attestation capabilities:

- **Automatic SBOM Generation**: Native BuildKit SBOM attestations for all images
- **Build Provenance**: SLSA build attestations documenting the complete build process
- **Docker Hub Integration**: Attestations automatically visible on Docker Hub
- **Multi-Architecture Coverage**: Attestations generated for all supported platforms
- **Supply Chain Security**: Built-in verification without external tools

#### Viewing Attestations
```bash
# View BuildKit SBOM attestations
docker buildx imagetools inspect liskl/base:alpine-3.22.1 --format '{{json .SBOM}}'

# View BuildKit provenance attestations
docker buildx imagetools inspect liskl/base:alpine-3.22.1 --format '{{json .Provenance}}'

# Test attestation verification locally
./build-local.sh -t
```

### Immutable Tag Protection
The project includes protection for immutable Docker Hub tags to prevent accidental overwrites:

- **Protected Pattern**: `^alpine-[0-9]+\.[0-9]+\.[0-9]+$` (e.g., `alpine-3.22.1`, `alpine-3.21.4`)
- **Detection Script**: `scripts/check-immutable-tags.sh` validates tags before push operations
- **CI/CD Integration**: Workflows automatically check tag status and skip protected tags gracefully

#### CI/CD Workflow Behavior
- **Master Branch**: Checks each `alpine-X.Y.Z` tag before building; skips existing immutable tags
- **Feature Branches**: Safety verification ensures commit-prefixed tags don't conflict with immutable patterns
- **Graceful Handling**: Failed tag checks don't fail the entire workflow; clear status messages provided
- **Latest Tag**: Special handling for `latest` tag (only pushed with Alpine 3.22.1 if safe)

#### Using Immutable Tag Detection
```bash
# Check if tags are immutable and exist on Docker Hub
./scripts/check-immutable-tags.sh alpine-3.22.1 alpine-3.21.4

# JSON output for programmatic use
./scripts/check-immutable-tags.sh --json alpine-3.22.1

# Debug mode for troubleshooting
./scripts/check-immutable-tags.sh --debug alpine-3.22.1

# Custom registry
./scripts/check-immutable-tags.sh --registry myregistry/base alpine-3.22.1

# Run unit tests
./scripts/test-check-immutable-tags.sh
```

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

## Issue Work and Branch Management

### Branch Creation Best Practices

**IMPORTANT**: All issue work should be done on fresh branches that are:
- ✅ **Based on `origin/master`**: Always start from the latest master branch
- ✅ **Up-to-date**: Ensure your local master is synced with `origin/master`
- ✅ **Clean start**: Create new branch immediately after syncing

#### Recommended Workflow
```bash
# 1. Switch to master and sync with origin
git checkout master
git pull origin master

# 2. Create new feature branch immediately
git checkout -b feat/your-feature-name

# 3. Work on your feature
# ... make changes, commits, etc.

# 4. Before creating PR, rebase if needed
git fetch origin
git rebase origin/master

# 5. Push and create PR
git push -u origin feat/your-feature-name
```

#### Why This Matters
- **Prevents Conflicts**: Starting from latest master reduces merge conflicts
- **Clean History**: Linear commit history that's easy to review
- **Easier Rebasing**: Fewer complications when resolving conflicts
- **Consistent Base**: All team members work from same foundation

#### Common Pitfalls to Avoid
- ❌ Creating branches from outdated local master
- ❌ Working on branches that are many commits behind master
- ❌ Merging instead of rebasing when conflicts arise
- ❌ Creating branches from other feature branches

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