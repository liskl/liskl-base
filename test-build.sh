#!/bin/bash

# Quick test script for common build scenarios

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Alpine Base Image Quick Test Builder${NC}"
echo -e "${BLUE}===================================${NC}"

echo "Select a test scenario:"
echo "1) Build amd64 only (fastest)"
echo "2) Build arm64 only" 
echo "3) Build amd64 + arm64 (common platforms)"
echo "4) Build all architectures"
echo "5) Test with attestation verification"
echo "6) Custom build"

read -p "Enter choice (1-6): " choice

case $choice in
    1)
        echo -e "${BLUE}Building AMD64 only...${NC}"
        ./build-local.sh -a amd64
        ;;
    2)
        echo -e "${BLUE}Building ARM64 only...${NC}"
        ./build-local.sh -a arm64
        ;;
    3)
        echo -e "${BLUE}Building AMD64 and ARM64...${NC}"
        ./build-local.sh -a amd64
        ./build-local.sh -a arm64
        ;;
    4)
        echo -e "${BLUE}Building all architectures...${NC}"
        ./build-local.sh
        ;;
    5)
        echo -e "${BLUE}Building with attestation testing...${NC}"
        ./build-local.sh -a amd64 -t
        ;;
    6)
        echo -e "${YELLOW}Custom build options:${NC}"
        echo "Examples:"
        echo "  ./build-local.sh -v 3.21.4 -a arm64    # Specific version and arch"
        echo "  ./build-local.sh -A                     # All versions"
        echo "  ./build-local.sh -p -t                  # Push and test"
        echo ""
        echo "Run './build-local.sh --help' for full options"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Test completed!${NC}"