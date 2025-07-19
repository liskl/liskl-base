# liskl-base

Minimal Alpine Linux base Docker images built from scratch using Alpine minirootfs tarballs.

## Overview

This project creates lightweight, security-focused base Docker images using Alpine Linux minirootfs archives. Images are built for multiple Alpine versions and architectures, providing a comprehensive collection of minimal base images for containerized applications.

## Supported Versions and Architectures

### Alpine Linux Versions
- **3.14.3** - 3.22.1 (latest patch versions for each minor release)
- **3.22.1** - Latest stable release (tagged as `latest`)

### Architectures
- **linux/386** (x86)
- **linux/amd64** (x86_64)
- **linux/arm/v6** (armv7)
- **linux/arm/v7** (armhf)
- **linux/arm64/v8** (aarch64)
- **linux/ppc64le** (ppc64le)
- **linux/s390x** (s390x)
- **linux/riscv64** (riscv64) - Alpine 3.20+ only

## Image Tags

### Production Images (from master branch)
```bash
# Latest stable Alpine version
docker pull liskl/base:latest

# Specific Alpine versions
docker pull liskl/base:alpine-3.22.1
docker pull liskl/base:alpine-3.21.4
docker pull liskl/base:alpine-3.20.7
# ... (all versions 3.14.3 through 3.22.1)
```

### Development Images (from feature branches)
```bash
# Development builds with commit SHA
docker pull liskl/base:a1b2c3d-alpine-3.22.1
```

## Usage

### Basic Usage
```dockerfile
FROM liskl/base:alpine-3.22.1

# Add your application
COPY app /usr/local/bin/
CMD ["app"]
```

### Multi-stage Builds
```dockerfile
# Build stage
FROM alpine:3.22 AS builder
RUN apk add --no-cache build-base
COPY . /src
WORKDIR /src
RUN make build

# Runtime stage
FROM liskl/base:alpine-3.22.1
COPY --from=builder /src/dist/app /usr/local/bin/
CMD ["app"]
```

## Building Locally

### Prerequisites
- Docker with BuildKit enabled
- Bash shell

### Download Alpine Rootfs
```bash
# Download all supported Alpine versions
./download.sh
```

### Build Specific Version
```bash
# Build for default architecture (amd64)
docker build --build-arg alpine_version=3.22.1 -t liskl/base:alpine-3.22.1 .

# Build for specific architecture
docker build --platform linux/arm/v7 --build-arg alpine_version=3.22.1 -t liskl/base:alpine-3.22.1-armhf .
```

### Build Multi-platform
```bash
# Setup buildx (one time)
docker buildx create --use

# Build and push multi-platform image (all architectures)
docker buildx build \
  --platform linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x,linux/riscv64 \
  --build-arg alpine_version=3.22.1 \
  -t liskl/base:alpine-3.22.1 \
  --push .

# Build for specific architectures only
docker buildx build \
  --platform linux/amd64,linux/arm64/v8 \
  --build-arg alpine_version=3.22.1 \
  -t liskl/base:alpine-3.22.1 \
  --push .
```

## CI/CD

This repository uses GitHub Actions for automated building and publishing:

- **Master Branch**: Builds and publishes all Alpine versions as production images
- **Feature Branches**: Builds development images tagged with commit SHA
- **Manual Triggers**: Workflows can be triggered manually via GitHub Actions UI

### Build Matrix
Each workflow run builds:
- 9 Alpine versions (3.14.3 through 3.22.1)
- 7-8 architectures (7 base + 1 conditional riscv64 for Alpine 3.20+)
- **Total**: 63-66 images per workflow run

## Image Details

### Base Configuration
- **Base**: Built `FROM scratch` for minimal footprint
- **Shell**: `/bin/sh` (default entrypoint)
- **Package Manager**: `apk` (Alpine Package Keeper)
- **C Library**: `musl libc`
- **Init System**: `busybox`

### Build Metadata
Each image includes build information in `/etc/build_release`:
```bash
docker run --rm liskl/base:alpine-3.22.1 cat /etc/build_release
```

### Image Sizes
Typical compressed image sizes:
- **386**: ~2.4MB
- **amd64**: ~2.7MB
- **arm/v6**: ~2.4MB
- **arm/v7**: ~2.5MB
- **arm64/v8**: ~2.6MB
- **ppc64le**: ~2.7MB
- **s390x**: ~2.4MB
- **riscv64**: ~3.4MB

## Security

### Current Implementation
- Built from official Alpine Linux minirootfs tarballs
- Minimal attack surface (no unnecessary packages)
- Regular updates following Alpine Linux security advisories
- Multi-architecture support for diverse deployment environments

### SBOM Generation (Implemented)
All images include comprehensive Software Bill of Materials (SBOM) for supply chain security:

- **SPDX Format**: Industry-standard SBOM format for compliance frameworks
- **CycloneDX Format**: Enhanced tool compatibility and ecosystem integration
- **Automated Generation**: Generated during every CI/CD build process
- **Cryptographic Attestation**: Signed and attached using cosign keyless signing
- **Multi-Architecture Coverage**: SBOMs generated for all supported platforms
- **Vulnerability Scanning Ready**: Compatible with grype, snyk, and other security tools

#### SBOM Verification Examples
```bash
# Verify SBOM attestations exist
cosign verify-attestation --type spdx liskl/base:alpine-3.22.1
cosign verify-attestation --type cyclonedx liskl/base:alpine-3.22.1

# Extract SBOM for vulnerability scanning
cosign verify-attestation --type spdx liskl/base:alpine-3.22.1 \
  | jq -r '.payload | @base64d | fromjson | .predicate' > sbom.spdx.json

# Run vulnerability scan with grype
grype sbom:sbom.spdx.json --fail-on critical

# Use provided verification script
./scripts/verify-sbom.sh alpine-3.22.1
```

### Security Features (Planned)
- **Build Attestations** (Issue #12): SLSA provenance attestations for build integrity verification and enterprise compliance

## Development

### Project Structure
```
.
├── Dockerfile              # Multi-platform Dockerfile
├── download.sh             # Alpine rootfs download script
├── rootfs/                 # Alpine minirootfs tarballs
├── scripts/
│   └── verify-sbom.sh     # SBOM verification and extraction script
├── .github/workflows/      # CI/CD workflows with SBOM generation
└── CLAUDE.md              # AI assistant guidelines
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `docker build`
5. Submit a pull request

### Commit Messages
This project uses [Conventional Commits](https://conventionalcommits.org/):
```bash
feat: add support for Alpine 3.23
fix: correct armhf build argument handling
docs: update README with new examples
ci: optimize workflow build matrix
```

## License

This project is open source. Alpine Linux is distributed under its own license terms.

## Links

- [Alpine Linux](https://alpinelinux.org/)
- [Docker Hub](https://hub.docker.com/r/liskl/base)
- [GitHub Repository](https://github.com/liskl/liskl-base)
