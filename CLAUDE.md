# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker base image project that creates minimal Alpine Linux containers. The project builds base Docker images using Alpine Linux minirootfs tarballs for both x86_64 and armhf architectures.

## Architecture

- **Dockerfile**: Creates a minimal Alpine Linux base image from scratch using minirootfs tarballs
- **download.sh**: Downloads Alpine Linux minirootfs archives for different architectures 
- **rootfs/**: Contains Alpine Linux minirootfs tarballs (3.11.3 versions currently included)
- **GitHub Actions**: Automated CI/CD workflows for building and publishing Docker images

## Build Commands

### Docker Image Building
```bash
# Build the Docker image locally
docker build -t liskl/base .

# Build with specific architecture
docker build --build-arg ARCH=armhf -t liskl/base:armhf .

# Build with custom Alpine version
docker build --build-arg alpine_version=3.14.3 -t liskl/base:3.14.3 .
```

### Download Alpine Rootfs
```bash
# Download required Alpine minirootfs archives
./download.sh
```

## CI/CD Workflows

The project uses GitHub Actions with two workflows:

1. **Master Branch** (on-push-master_build-push.yaml): Builds and pushes images tagged as `latest` and commit SHA
2. **Feature Branches** (on-push-non-master_build-push.yaml): Builds and pushes images tagged with branch name and commit SHA

Both workflows publish to Docker Hub.

## Build Arguments

- `RELEASE_VERSION`: Git commit SHA (set by CI)
- `BRANCH`: Git branch name (set by CI)  
- `alpine_version`: Alpine Linux version (default: 3.11.3)
- `ARCH`: Target architecture (default: x86_64, also supports armhf)

## Image Details

The resulting Docker image:
- Built FROM scratch for minimal size
- Uses Alpine Linux minirootfs as base layer
- Sets environment variables for build tracking
- Default entrypoint: `/bin/sh`
- Includes build metadata in `/etc/build_release`

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