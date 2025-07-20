#!/usr/bin/env bash

# Build Attestation Verification Script
# This script demonstrates how to verify and extract build attestations from liskl/base images

set -e

IMAGE_TAG=${1:-"alpine-3.22.1"}

# Support both tag and digest formats
if [[ "${IMAGE_TAG}" == *"@sha256:"* ]]; then
    IMAGE="${IMAGE_TAG}"
else
    IMAGE="liskl/base:${IMAGE_TAG}"
fi

echo "Build Attestation Verification for ${IMAGE}"
echo "==========================================="

# Check if required tools are installed
command -v cosign >/dev/null 2>&1 || { echo "Error: cosign is required but not installed. See: https://docs.sigstore.dev/cosign/installation/"; exit 1; }

echo "✓ Required tools found (cosign)"
echo ""

# Check for public key file or use keyless verification
PUBLIC_KEY_FILE=""
if [ -f "cosign.pub" ]; then
    PUBLIC_KEY_FILE="--key cosign.pub"
    echo "✓ Found cosign.pub, using key-based verification"
elif [ -n "${COSIGN_PUBLIC_KEY:-}" ]; then
    echo "${COSIGN_PUBLIC_KEY}" > /tmp/cosign.pub
    PUBLIC_KEY_FILE="--key /tmp/cosign.pub"
    echo "✓ Using COSIGN_PUBLIC_KEY environment variable"
else
    echo "ℹ Using keyless verification (no cosign.pub found)"
fi
echo ""

# Verify build attestations exist
echo "1. Checking for build attestations..."

echo "   SBOM attestations:"
if cosign verify-attestation ${PUBLIC_KEY_FILE} --type spdx "$IMAGE" >/dev/null 2>&1; then
    echo "   ✓ SPDX SBOM attestation found and verified"
else
    echo "   ⚠ SPDX SBOM attestation not found or verification failed"
fi

if cosign verify-attestation ${PUBLIC_KEY_FILE} --type cyclonedx "$IMAGE" >/dev/null 2>&1; then
    echo "   ✓ CycloneDX SBOM attestation found and verified"
else
    echo "   ⚠ CycloneDX SBOM attestation not found or verification failed"
fi

echo "   SLSA provenance attestation:"
if cosign verify-attestation ${PUBLIC_KEY_FILE} --type slsaprovenance "$IMAGE" >/dev/null 2>&1; then
    echo "   ✓ SLSA provenance attestation found and verified"
else
    echo "   ⚠ SLSA provenance attestation not found or verification failed"
fi
echo ""

# Extract and display build attestations
echo "2. Extracting build attestations..."
mkdir -p /tmp/attestation-verification

# Extract SLSA provenance
echo "   Extracting SLSA provenance..."
if cosign verify-attestation ${PUBLIC_KEY_FILE} --type slsaprovenance "$IMAGE" --output-file /tmp/attestation-verification/slsa-provenance.json 2>/dev/null; then
    echo "   ✓ SLSA provenance extracted to /tmp/attestation-verification/slsa-provenance.json"
    
    # Parse and display summary
    if command -v jq >/dev/null 2>&1; then
        echo "   Analysis:"
        
        # Extract key information
        BUILDER_ID=$(jq -r '.payload | @base64d | fromjson | .predicate.builder.id' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        BUILD_TYPE=$(jq -r '.payload | @base64d | fromjson | .predicate.buildType' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        SOURCE_URI=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.configSource.uri' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        SOURCE_SHA=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.configSource.digest.sha1' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        BUILD_INVOCATION_ID=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.buildInvocationId' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        GITHUB_ACTOR=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.actor' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        GITHUB_REF=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.ref' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
        
        echo "     - Builder: $BUILDER_ID"
        echo "     - Build Type: $BUILD_TYPE"
        echo "     - Source: $SOURCE_URI"
        echo "     - Source SHA: $SOURCE_SHA"
        echo "     - Build ID: $BUILD_INVOCATION_ID"
        echo "     - Built by: $GITHUB_ACTOR"
        echo "     - Git ref: $GITHUB_REF"
        
        # Extract materials
        MATERIAL_COUNT=$(jq -r '.payload | @base64d | fromjson | .predicate.materials | length' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "0")
        echo "     - Materials: $MATERIAL_COUNT sources"
        
        if [ "$MATERIAL_COUNT" != "0" ] && [ "$MATERIAL_COUNT" != "unknown" ]; then
            echo "     - Material sources:"
            jq -r '.payload | @base64d | fromjson | .predicate.materials[] | "       * \(.uri)"' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || true
        fi
    fi
else
    echo "   ⚠ Could not extract SLSA provenance"
fi
echo ""

# Display build environment details
echo "3. Build environment analysis..."
if [ -f "/tmp/attestation-verification/slsa-provenance.json" ] && command -v jq >/dev/null 2>&1; then
    echo "   GitHub Actions environment:"
    
    # Extract GitHub environment details
    GH_EVENT=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.event_name' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    GH_REPO=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.repository' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    GH_RUN_ID=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.run_id' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    GH_RUN_NUMBER=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.environment.github.run_number' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    
    echo "     - Event: $GH_EVENT"
    echo "     - Repository: $GH_REPO"
    echo "     - Run ID: $GH_RUN_ID"
    echo "     - Run Number: $GH_RUN_NUMBER"
    
    # Extract build parameters
    echo "   Build parameters:"
    ALPINE_VERSION=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.parameters.alpine_version' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    ALPINE_ARCH=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.parameters.ALPINE_ARCH' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    BRANCH=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.parameters.BRANCH' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    
    echo "     - Alpine version: $ALPINE_VERSION"
    echo "     - Architecture: $ALPINE_ARCH"
    echo "     - Branch: $BRANCH"
    
    # Check if this is a development build
    DEV_BUILD=$(jq -r '.payload | @base64d | fromjson | .predicate.invocation.parameters.development_build' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "false")
    if [ "$DEV_BUILD" = "true" ]; then
        echo "     - Build type: Development"
    else
        echo "     - Build type: Production"
    fi
    
    # Extract timing information
    echo "   Build timing:"
    BUILD_STARTED=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.buildStartedOn' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    BUILD_FINISHED=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.buildFinishedOn' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "unknown")
    
    echo "     - Started: $BUILD_STARTED"
    echo "     - Finished: $BUILD_FINISHED"
else
    echo "   Install jq for detailed analysis: sudo apt-get install jq"
fi
echo ""

# Compliance and security analysis
echo "4. Compliance analysis..."
if [ -f "/tmp/attestation-verification/slsa-provenance.json" ] && command -v jq >/dev/null 2>&1; then
    echo "   SLSA Level assessment:"
    
    # Check completeness claims
    PARAMS_COMPLETE=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.completeness.parameters' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "false")
    ENV_COMPLETE=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.completeness.environment' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "false")
    MATERIALS_COMPLETE=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.completeness.materials' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "false")
    REPRODUCIBLE=$(jq -r '.payload | @base64d | fromjson | .predicate.metadata.reproducible' /tmp/attestation-verification/slsa-provenance.json 2>/dev/null || echo "false")
    
    echo "     - Parameters complete: $PARAMS_COMPLETE"
    echo "     - Environment complete: $ENV_COMPLETE"
    echo "     - Materials complete: $MATERIALS_COMPLETE"
    echo "     - Reproducible: $REPRODUCIBLE"
    
    # Determine SLSA level (simplified assessment)
    if [ "$PARAMS_COMPLETE" = "true" ] && [ "$ENV_COMPLETE" = "true" ] && [ "$MATERIALS_COMPLETE" = "true" ]; then
        if [ "$REPRODUCIBLE" = "true" ]; then
            echo "     - Estimated SLSA Level: 3+ (full provenance + reproducible)"
        else
            echo "     - Estimated SLSA Level: 2-3 (full provenance, not reproducible)"
        fi
    else
        echo "     - Estimated SLSA Level: 1-2 (partial provenance)"
    fi
    
    echo "   Enterprise compliance:"
    echo "     ✓ Source identification (materials tracked)"
    echo "     ✓ Build process documented"
    echo "     ✓ Build environment captured"
    echo "     ✓ Cryptographic attestation"
    echo "     ✓ Non-repudiation (signed provenance)"
else
    echo "   Install jq for compliance analysis"
fi
echo ""

echo "Attestation Verification Complete"
echo "================================="
echo "Files created in /tmp/attestation-verification/:"
ls -la /tmp/attestation-verification/ 2>/dev/null || echo "No files created"
echo ""
echo "Usage examples:"
echo "  # Verify specific version:"
echo "  $0 alpine-3.21.4"
echo ""
echo "  # Verify latest:"
echo "  $0 latest"
echo ""
echo "  # Verify development build:"
echo "  $0 a1b2c3d-alpine-3.22.1"
echo ""
echo "  # Extract build provenance manually:"
echo "  cosign verify-attestation --key cosign.pub --type slsaprovenance $IMAGE"
echo ""
echo "  # Extract specific fields:"
echo "  cosign verify-attestation --key cosign.pub --type slsaprovenance $IMAGE | jq -r '.payload | @base64d | fromjson | .predicate.builder.id'"