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
- **Dual attestation strategy**: Both BuildKit and cosign SBOM attestations
- **BuildKit SBOMs**: Native Docker Hub format for automatic indexing and compliance display
- **Cosign SBOMs**: SPDX and CycloneDX formats for external tool compatibility
- **Automated generation**: Generated for every image during CI/CD builds
- **Multi-architecture coverage**: SBOMs for all supported platforms
- **Vulnerability ready**: Compatible with grype, snyk, and other scanners
- **Secure signing**: Uses image digests to prevent tag substitution attacks

### Build Attestations (Implemented)
- **Dual attestation strategy**: Both BuildKit and cosign SLSA provenance attestations
- **BuildKit provenance**: Native Docker Hub format for automatic compliance display
- **Cosign provenance**: Detailed SLSA v0.2 format with comprehensive build metadata
- **Supply chain transparency**: Full documentation of build process and materials
- **GitHub Actions integration**: Captures complete build environment details
- **Enterprise compliance**: Meets NIST and EU Cyber Resilience Act requirements
- **Non-repudiation**: Cryptographically signed build evidence
- **Multi-platform coverage**: Attestations for all architectures and Alpine versions

### Security Verification
```bash
# Verify cosign SBOM attestations (requires cosign.pub public key)
cosign verify-attestation --key cosign.pub --type spdx liskl/base:alpine-3.22.1
cosign verify-attestation --key cosign.pub --type cyclonedx liskl/base:alpine-3.22.1

# Verify cosign SLSA provenance attestation
cosign verify-attestation --key cosign.pub --type slsaprovenance liskl/base:alpine-3.22.1

# View BuildKit attestations (automatically generated and visible on Docker Hub)
docker buildx imagetools inspect liskl/base:alpine-3.22.1 --format '{{json .Provenance}}'
docker buildx imagetools inspect liskl/base:alpine-3.22.1 --format '{{json .SBOM}}'

# Extract SBOM for vulnerability scanning
cosign verify-attestation --key cosign.pub --type spdx liskl/base:alpine-3.22.1 \
  | jq -r '.payload | @base64d | fromjson | .predicate' > sbom.spdx.json

# Extract build provenance for compliance audit
cosign verify-attestation --key cosign.pub --type slsaprovenance liskl/base:alpine-3.22.1 \
  | jq -r '.payload | @base64d | fromjson | .predicate' > provenance.json

# Run vulnerability scan
grype sbom:sbom.spdx.json --fail-on critical

# Use verification scripts (auto-detect cosign.pub)
./scripts/verify-sbom.sh alpine-3.22.1          # SBOM verification
./scripts/verify-attestations.sh alpine-3.22.1  # Complete attestation analysis

# Generate cosign key pair for signing
./scripts/generate-cosign-keys.sh
```

### Required GitHub Configuration

#### GitHub Secrets (Private)
- **COSIGN_PRIVATE_KEY**: Private key for signing SBOMs (from cosign.key)
- **COSIGN_PASSWORD**: Password for the private key

#### GitHub Variables (Public)
- **COSIGN_PUBLIC_KEY**: Public key for verification (from cosign.pub)

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