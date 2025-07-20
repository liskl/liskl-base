#!/usr/bin/env bash

# Local SBOM Testing Script
# Tests SBOM generation without full CI/CD pipeline

set -e

echo "SBOM Local Testing"
echo "=================="

# Check if required tools are available
echo "1. Checking required tools..."
if ! command -v syft >/dev/null 2>&1; then
    echo "Installing syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is required"
    exit 1
fi

echo "✓ Tools available"
echo ""

# Build test image
echo "2. Building test image..."
docker build -t liskl-base-test:sbom-test \
  --build-arg alpine_version=3.22.1 \
  --build-arg ALPINE_ARCH=x86_64 \
  --build-arg RELEASE_VERSION=test \
  --build-arg BRANCH=sbom-support .

echo "✓ Test image built"
echo ""

# Generate SBOM
echo "3. Generating SBOM..."
mkdir -p /tmp/sbom-test

echo "   Generating SPDX format..."
syft liskl-base-test:sbom-test \
  --output spdx-json=/tmp/sbom-test/test-spdx.json

echo "   Generating CycloneDX format..."
syft liskl-base-test:sbom-test \
  --output cyclonedx-json=/tmp/sbom-test/test-cyclonedx.json

echo "✓ SBOMs generated"
echo ""

# Analyze SBOM content
echo "4. Analyzing SBOM content..."
if command -v jq >/dev/null 2>&1; then
    SPDX_PACKAGES=$(jq -r '.packages | length' /tmp/sbom-test/test-spdx.json)
    CYCLONEDX_COMPONENTS=$(jq -r '.components | length' /tmp/sbom-test/test-cyclonedx.json)
    
    echo "   SPDX packages: $SPDX_PACKAGES"
    echo "   CycloneDX components: $CYCLONEDX_COMPONENTS"
    
    echo "   Sample packages from SPDX:"
    jq -r '.packages[0:5] | .[] | "     - \(.name) (\(.versionInfo // "no version"))"' /tmp/sbom-test/test-spdx.json
else
    echo "   Install jq for detailed analysis: sudo apt-get install jq"
fi
echo ""

# Test vulnerability scanning if grype is available
echo "5. Testing vulnerability scanning..."
if command -v grype >/dev/null 2>&1; then
    echo "   Running grype scan..."
    grype sbom:/tmp/sbom-test/test-spdx.json --output table
    echo "✓ Vulnerability scan completed"
else
    echo "   Install grype for vulnerability scanning:"
    echo "   curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
fi
echo ""

echo "Test Summary"
echo "============"
echo "✓ Docker image built successfully"
echo "✓ SPDX SBOM generated"
echo "✓ CycloneDX SBOM generated"
echo ""
echo "Files created:"
ls -la /tmp/sbom-test/
echo ""
echo "Next steps:"
echo "- Commit and push to test CI/CD SBOM generation"
echo "- Verify cosign attestation in GitHub Actions"
echo "- Test with production images"

# Cleanup
echo ""
read -p "Remove test image and files? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi liskl-base-test:sbom-test >/dev/null 2>&1 || true
    rm -rf /tmp/sbom-test
    echo "✓ Cleanup completed"
fi