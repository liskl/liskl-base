# liskl-base

Minimal Alpine Linux base Docker images built from scratch using Alpine minirootfs tarballs.

## Overview

This project creates lightweight, security-focused base Docker images using Alpine Linux minirootfs archives. Images are built for multiple Alpine versions and architectures, providing a comprehensive collection of minimal base images for containerized applications.

## Supported Versions and Architectures

### Alpine Linux Versions
- **3.14.3** - 3.22.1 (latest patch versions for each minor release)
- **3.22.1** - Latest stable release (tagged as `latest`)

### Architectures
- **linux/amd64** (x86_64)
- **linux/arm/v7** (armhf)

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

# Build and push multi-platform image
docker buildx build \
  --platform linux/amd64,linux/arm/v7 \
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
- 2 architectures (amd64, arm/v7)
- **Total**: 18 images per workflow run

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
- **amd64**: ~2.7MB
- **arm/v7**: ~2.5MB

## Security

- Built from official Alpine Linux minirootfs tarballs
- Minimal attack surface (no unnecessary packages)
- Regular updates following Alpine Linux security advisories
- Multi-architecture support for diverse deployment environments

## Development

### Project Structure
```
.
├── Dockerfile              # Multi-platform Dockerfile
├── download.sh             # Alpine rootfs download script
├── rootfs/                 # Alpine minirootfs tarballs
├── .github/workflows/      # CI/CD workflows
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
