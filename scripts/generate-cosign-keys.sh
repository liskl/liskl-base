#!/usr/bin/env bash

# Cosign Key Generation Script
# Generates a key pair for signing SBOM attestations

set -e

echo "Cosign Key Pair Generation"
echo "========================="
echo ""

# Check if cosign is installed
if ! command -v cosign >/dev/null 2>&1; then
    echo "Error: cosign is required but not installed."
    echo "Install it from: https://docs.sigstore.dev/cosign/installation/"
    exit 1
fi

echo "✓ cosign found"
echo ""

# Generate key pair
echo "Generating cosign key pair..."
echo "You will be prompted to enter a password for the private key."
echo "This password will be stored as COSIGN_PASSWORD secret in GitHub."
echo ""

# Generate the key pair
cosign generate-key-pair

echo ""
echo "✅ Key pair generated successfully!"
echo ""

echo "GitHub Configuration Setup"
echo "=========================="
echo ""
echo "Add the following to your GitHub repository:"
echo ""
echo "SECRETS (Settings > Secrets and variables > Actions > Secrets):"
echo "1. COSIGN_PRIVATE_KEY"
echo "   Value: Copy the entire contents of cosign.key (including -----BEGIN... and -----END... lines)"
echo ""
echo "2. COSIGN_PASSWORD" 
echo "   Value: The password you just entered"
echo ""
echo "VARIABLES (Settings > Secrets and variables > Actions > Variables):"
echo "3. COSIGN_PUBLIC_KEY"
echo "   Value: Copy the entire contents of cosign.pub (including -----BEGIN... and -----END... lines)"
echo ""

echo "Setup Instructions:"
echo "1. Go to your GitHub repository"
echo "2. Click Settings > Secrets and variables > Actions"
echo "3. Add secrets in the 'Secrets' tab"
echo "4. Add variables in the 'Variables' tab"
echo "5. Use the exact names above"
echo ""

echo "Generated files:"
echo "- cosign.key (private key - add as COSIGN_PRIVATE_KEY secret)"
echo "- cosign.pub (public key - for verification, optionally add as COSIGN_PUBLIC_KEY)"
echo ""

echo "⚠️  Security Notes:"
echo "- Keep cosign.key secure and never commit it to git"
echo "- The public key (cosign.pub) can be shared for verification"
echo "- Delete the local cosign.key file after adding it to GitHub secrets"
echo ""

echo "Verification Commands:"
echo "====================="
echo ""
echo "# Verify SBOM attestation with public key (after secrets are added)"
echo "cosign verify-attestation --key cosign.pub --type spdx liskl/base:alpine-3.22.1"
echo ""
echo "# Extract SBOM for vulnerability scanning"
echo "cosign verify-attestation --key cosign.pub --type spdx liskl/base:alpine-3.22.1 \\"
echo "  | jq -r '.payload | @base64d | fromjson | .predicate' > sbom.spdx.json"
echo ""

# Add warning about file cleanup
echo "⚠️  IMPORTANT: Remember to delete cosign.key after adding it to GitHub secrets!"
echo "   rm cosign.key"