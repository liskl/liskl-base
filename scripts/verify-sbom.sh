#!/usr/bin/env bash

# SBOM Verification Script
# This script demonstrates how to verify and extract SBOMs from liskl/base images

set -e

IMAGE_TAG=${1:-"alpine-3.22.1"}

# Support both tag and digest formats
if [[ "${IMAGE_TAG}" == *"@sha256:"* ]]; then
    IMAGE="${IMAGE_TAG}"
else
    IMAGE="liskl/base:${IMAGE_TAG}"
fi

echo "SBOM Verification for ${IMAGE}"
echo "================================"

# Check if required tools are installed
command -v cosign >/dev/null 2>&1 || { echo "Error: cosign is required but not installed. See: https://docs.sigstore.dev/cosign/installation/"; exit 1; }
command -v syft >/dev/null 2>&1 || { echo "Error: syft is required but not installed. See: https://github.com/anchore/syft#installation"; exit 1; }

echo "✓ Required tools found (cosign, syft)"
echo ""

# Verify SBOM attestations exist
echo "1. Checking for SBOM attestations..."
echo "   SPDX attestation:"
if cosign verify-attestation --type spdx "$IMAGE" >/dev/null 2>&1; then
    echo "   ✓ SPDX SBOM attestation found"
else
    echo "   ⚠ SPDX SBOM attestation not found (may be expected for local builds)"
fi

echo "   CycloneDX attestation:"
if cosign verify-attestation --type cyclonedx "$IMAGE" >/dev/null 2>&1; then
    echo "   ✓ CycloneDX SBOM attestation found"
else
    echo "   ⚠ CycloneDX SBOM attestation not found (may be expected for local builds)"
fi
echo ""

# Extract and display SBOM attestations
echo "2. Extracting SBOM attestations..."
mkdir -p /tmp/sbom-verification

# Extract SPDX SBOM
echo "   Extracting SPDX SBOM..."
if cosign verify-attestation --type spdx "$IMAGE" --output-file /tmp/sbom-verification/spdx-attestation.json 2>/dev/null; then
    echo "   ✓ SPDX SBOM extracted to /tmp/sbom-verification/spdx-attestation.json"
    
    # Parse and display summary
    if command -v jq >/dev/null 2>&1; then
        SPDX_COMPONENTS=$(jq -r '.payload | @base64d | fromjson | .predicate.packages | length' /tmp/sbom-verification/spdx-attestation.json 2>/dev/null || echo "unknown")
        echo "     - Components found: $SPDX_COMPONENTS"
    fi
else
    echo "   ⚠ Could not extract SPDX SBOM"
fi

# Extract CycloneDX SBOM
echo "   Extracting CycloneDX SBOM..."
if cosign verify-attestation --type cyclonedx "$IMAGE" --output-file /tmp/sbom-verification/cyclonedx-attestation.json 2>/dev/null; then
    echo "   ✓ CycloneDX SBOM extracted to /tmp/sbom-verification/cyclonedx-attestation.json"
    
    # Parse and display summary
    if command -v jq >/dev/null 2>&1; then
        CYCLONEDX_COMPONENTS=$(jq -r '.payload | @base64d | fromjson | .predicate.components | length' /tmp/sbom-verification/cyclonedx-attestation.json 2>/dev/null || echo "unknown")
        echo "     - Components found: $CYCLONEDX_COMPONENTS"
    fi
else
    echo "   ⚠ Could not extract CycloneDX SBOM"
fi
echo ""

# Generate local SBOM for comparison
echo "3. Generating local SBOM for comparison..."
echo "   Creating SPDX SBOM..."
syft "$IMAGE" --output spdx-json --file /tmp/sbom-verification/local-spdx.json
echo "   ✓ Local SPDX SBOM created at /tmp/sbom-verification/local-spdx.json"

echo "   Creating CycloneDX SBOM..."
syft "$IMAGE" --output cyclonedx-json --file /tmp/sbom-verification/local-cyclonedx.json
echo "   ✓ Local CycloneDX SBOM created at /tmp/sbom-verification/local-cyclonedx.json"

# Display local SBOM summary
if command -v jq >/dev/null 2>&1; then
    LOCAL_SPDX_PACKAGES=$(jq -r '.packages | length' /tmp/sbom-verification/local-spdx.json 2>/dev/null || echo "unknown")
    LOCAL_CYCLONEDX_COMPONENTS=$(jq -r '.components | length' /tmp/sbom-verification/local-cyclonedx.json 2>/dev/null || echo "unknown")
    echo "   Local SPDX packages: $LOCAL_SPDX_PACKAGES"
    echo "   Local CycloneDX components: $LOCAL_CYCLONEDX_COMPONENTS"
fi
echo ""

# Vulnerability scanning example
echo "4. Example vulnerability scanning..."
echo "   Note: Install grype (https://github.com/anchore/grype) for vulnerability scanning"
if command -v grype >/dev/null 2>&1; then
    echo "   Running vulnerability scan..."
    grype sbom:/tmp/sbom-verification/local-spdx.json --output table --fail-on critical
    echo "   ✓ Vulnerability scan completed"
else
    echo "   ⚠ grype not found - install for vulnerability scanning: curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
fi
echo ""

echo "SBOM Verification Complete"
echo "=========================="
echo "Files created in /tmp/sbom-verification/:"
ls -la /tmp/sbom-verification/ 2>/dev/null || echo "No files created"
echo ""
echo "Usage examples:"
echo "  # Verify specific version:"
echo "  $0 alpine-3.21.4"
echo ""
echo "  # Verify latest:"
echo "  $0 latest"
echo ""
echo "  # Extract just the SBOM from attestation:"
echo "  cosign verify-attestation --type spdx $IMAGE | jq -r '.payload | @base64d | fromjson | .predicate'"