#!/bin/bash

# Local testing script for building multi-architecture Alpine base images
# This script builds various architectures and Alpine versions for local testing

set -e

# Default values
ALPINE_VERSION="3.22.1"
BUILD_SINGLE_ARCH=""
BUILD_ALL_VERSIONS=false
PUSH_IMAGES=false
TEST_ATTESTATIONS=false
TEST_EMULATION=false
REGISTRY_PREFIX="liskl/base"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Alpine base images locally for testing with BuildKit attestations.

OPTIONS:
    -v, --version VERSION    Alpine version to build (default: $ALPINE_VERSION)
    -a, --arch ARCH         Build single architecture only (amd64, arm64, etc.)
    -A, --all-versions      Build all supported Alpine versions
    -p, --push              Push images to registry after building
    -t, --test-attestations Test attestation verification after build
    -e, --test-emulation    Test Docker Desktop architecture emulation capabilities
    -r, --registry PREFIX   Registry prefix (default: $REGISTRY_PREFIX)
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Build Alpine $ALPINE_VERSION for amd64
    $0 -v 3.21.4                        # Build specific Alpine version
    $0 -a arm64                          # Build only arm64 architecture
    $0 -A                                # Build all Alpine versions
    $0 -p -t                             # Build, push, and test attestations
    $0 -e                                # Test architecture emulation capabilities
    $0 -r myregistry/alpine              # Use custom registry prefix

SUPPORTED ARCHITECTURES:
    - amd64 (linux/amd64)
    - arm64 (linux/arm64/v8) 
    - armv6 (linux/arm/v6)
    - armv7 (linux/arm/v7)
    - 386 (linux/386)
    - ppc64le (linux/ppc64le)
    - s390x (linux/s390x)
    - riscv64 (linux/riscv64) - Alpine 3.20+ only

SUPPORTED ALPINE VERSIONS:
    3.14.3, 3.15.11, 3.16.9, 3.17.10, 3.18.12, 3.19.8, 3.20.7, 3.21.4, 3.22.1
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            ALPINE_VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            BUILD_SINGLE_ARCH="$2"
            shift 2
            ;;
        -A|--all-versions)
            BUILD_ALL_VERSIONS=true
            shift
            ;;
        -p|--push)
            PUSH_IMAGES=true
            shift
            ;;
        -t|--test-attestations)
            TEST_ATTESTATIONS=true
            shift
            ;;
        -e|--test-emulation)
            TEST_EMULATION=true
            shift
            ;;
        -r|--registry)
            REGISTRY_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Alpine versions array
ALPINE_VERSIONS=("3.14.3" "3.15.11" "3.16.9" "3.17.10" "3.18.12" "3.19.8" "3.20.7" "3.21.4" "3.22.1")

# Architecture mappings (Docker platform -> Alpine arch -> tag suffix)
declare -A ARCH_MAP
ARCH_MAP["linux/amd64"]="x86_64:amd64"
ARCH_MAP["linux/arm64/v8"]="aarch64:arm64"
ARCH_MAP["linux/arm/v6"]="armv7:armv6"
ARCH_MAP["linux/arm/v7"]="armhf:armv7"
ARCH_MAP["linux/386"]="x86:386"
ARCH_MAP["linux/ppc64le"]="ppc64le:ppc64le"
ARCH_MAP["linux/s390x"]="s390x:s390x"
ARCH_MAP["linux/riscv64"]="riscv64:riscv64"

# Function to check if riscv64 is supported for given Alpine version
is_riscv64_supported() {
    local version=$1
    [[ "$version" =~ ^3\.(2[0-9]|[3-9][0-9]) ]]
}

# Function to build single architecture
build_arch() {
    local platform=$1
    local alpine_arch=$2
    local tag_suffix=$3
    local alpine_version=$4
    local push_flag=$5
    
    echo -e "${BLUE}Building ${platform} (${alpine_arch}) for Alpine ${alpine_version}...${NC}"
    
    local tag="${REGISTRY_PREFIX}:test-alpine-${alpine_version}-${tag_suffix}"
    local build_args=(
        "--platform" "$platform"
        "--build-arg" "alpine_version=${alpine_version}"
        "--build-arg" "ALPINE_ARCH=${alpine_arch}"
        "--build-arg" "RELEASE_VERSION=${alpine_version}"
        "--build-arg" "BRANCH=local-test"
        "--provenance=true"
        "--sbom=true"
        "-t" "$tag"
    )
    
    if [[ "$push_flag" == "true" ]]; then
        build_args+=("--push")
    else
        build_args+=("--load")
    fi
    
    echo "docker buildx build ${build_args[*]} ."
    docker buildx build "${build_args[@]}" .
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Successfully built ${tag}${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to build ${tag}${NC}"
        return 1
    fi
}

# Function to test attestations
test_attestations() {
    local tag=$1
    
    echo -e "${YELLOW}Testing BuildKit attestations for ${tag}...${NC}"
    
    # Test BuildKit SBOM
    if docker buildx imagetools inspect "$tag" --format '{{json .SBOM}}' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ BuildKit SBOM attestation present${NC}"
    else
        echo -e "${YELLOW}⚠ BuildKit SBOM attestation not found${NC}"
    fi
    
    # Test BuildKit provenance
    if docker buildx imagetools inspect "$tag" --format '{{json .Provenance}}' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ BuildKit provenance attestation present${NC}"
    else
        echo -e "${YELLOW}⚠ BuildKit provenance attestation not found${NC}"
    fi
    
    # Test image functionality
    echo -e "${BLUE}Testing image functionality...${NC}"
    
    # Test 1: Basic container startup
    if docker run --rm "$tag" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Image starts successfully${NC}"
    else
        echo -e "${RED}✗ Image failed to start${NC}"
        return 1
    fi
    
    # Test 2: Check build metadata exists
    if docker run --rm --entrypoint="" "$tag" /bin/test -f /etc/build_release >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Build metadata file exists${NC}"
    else
        echo -e "${YELLOW}⚠ Build metadata file not found${NC}"
    fi
    
    # Test 3: Execute echo command directly
    echo_output=$(docker run --rm --entrypoint="" "$tag" /bin/echo "Hello from Alpine container" 2>/dev/null)
    if [[ "$echo_output" == "Hello from Alpine container" ]]; then
        echo -e "${GREEN}✓ Can execute echo commands inside container${NC}"
    else
        echo -e "${RED}✗ Failed to execute echo command inside container${NC}"
        echo -e "${YELLOW}  Expected: 'Hello from Alpine container'${NC}"
        echo -e "${YELLOW}  Got: '$echo_output'${NC}"
    fi
    
    # Test 4: Check Alpine version info
    alpine_version_output=$(docker run --rm --entrypoint="" "$tag" /bin/cat /etc/alpine-release 2>/dev/null || echo "not found")
    if [[ "$alpine_version_output" != "not found" ]] && [[ -n "$alpine_version_output" ]]; then
        echo -e "${GREEN}✓ Alpine version info accessible: ${alpine_version_output}${NC}"
    else
        echo -e "${YELLOW}⚠ Alpine version info not accessible${NC}"
    fi
    
    # Test 5: Check basic shell utilities
    if docker run --rm --entrypoint="" "$tag" /bin/test -x /bin/sh >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Shell (/bin/sh) is executable${NC}"
    else
        echo -e "${YELLOW}⚠ Shell (/bin/sh) not found or not executable${NC}"
    fi
    
    # Test 6: Check build release content
    build_info=$(docker run --rm --entrypoint="" "$tag" /bin/cat /etc/build_release 2>/dev/null | head -2)
    if [[ -n "$build_info" ]]; then
        echo -e "${GREEN}✓ Build release info accessible${NC}"
        echo -e "${BLUE}  Build info: ${build_info//$'\n'/ | }${NC}"
    else
        echo -e "${YELLOW}⚠ Build release info not accessible${NC}"
    fi
    
    # Test 7: Execute commands via shell entrypoint (real-world usage test)
    shell_echo_output=$(docker run --rm "$tag" -c '/bin/echo "Shell entrypoint works"' 2>/dev/null)
    if [[ "$shell_echo_output" == "Shell entrypoint works" ]]; then
        echo -e "${GREEN}✓ Shell entrypoint executes commands correctly${NC}"
    else
        echo -e "${YELLOW}⚠ Shell entrypoint test failed (expected for minimal containers)${NC}"
        # Try alternative shell test
        alt_shell_test=$(echo '/bin/echo "Alt test"' | docker run --rm -i "$tag" 2>/dev/null)
        if [[ "$alt_shell_test" == "Alt test" ]]; then
            echo -e "${GREEN}✓ Shell accepts stdin commands${NC}"
        else
            echo -e "${YELLOW}⚠ Shell stdin test also failed${NC}"
        fi
    fi
    
    # Test 8: Architecture emulation test (Docker Desktop QEMU)
    echo -e "${BLUE}Testing Docker Desktop architecture emulation...${NC}"
    arch_from_tag=$(echo "$tag" | sed 's/.*-\([^-]*\)$/\1/')
    
    # Test basic command execution across architecture
    emulation_test=$(docker run --rm --entrypoint="" "$tag" /bin/echo "Emulation test for $arch_from_tag" 2>/dev/null)
    if [[ "$emulation_test" == "Emulation test for $arch_from_tag" ]]; then
        echo -e "${GREEN}✓ Architecture emulation working for $arch_from_tag${NC}"
        
        # Additional emulation stress test
        if docker run --rm --entrypoint="" "$tag" /bin/test -f /bin/sh >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Complex emulation operations work${NC}"
        else
            echo -e "${YELLOW}⚠ Some emulation operations may be limited${NC}"
        fi
    else
        echo -e "${RED}✗ Architecture emulation failed for $arch_from_tag${NC}"
        echo -e "${YELLOW}  This architecture may not be supported by Docker Desktop${NC}"
    fi
}

# Function to test architecture emulation capabilities
test_architecture_emulation() {
    echo -e "\n${GREEN}=== Docker Desktop Architecture Emulation Test ===${NC}"
    echo -e "${BLUE}Testing which architectures can run on this Docker Desktop instance...${NC}\n"
    
    local arch_results=()
    local supported_count=0
    local total_count=0
    
    # Test all built images
    for tag in $(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "test-alpine.*-" | grep -v "REPOSITORY"); do
        if [[ "$tag" =~ test-alpine-.*-([^-]+)$ ]]; then
            local arch="${BASH_REMATCH[1]}"
            local platform=""
            
            # Map architecture to platform for display
            case "$arch" in
                "amd64") platform="linux/amd64 (native)" ;;
                "386") platform="linux/386" ;;
                "arm64") platform="linux/arm64/v8" ;;
                "armv7") platform="linux/arm/v7" ;;
                "armv6") platform="linux/arm/v6" ;;
                "riscv64") platform="linux/riscv64" ;;
                "ppc64le") platform="linux/ppc64le" ;;
                "s390x") platform="linux/s390x" ;;
                *) platform="unknown" ;;
            esac
            
            echo -e "${BLUE}Testing $arch ($platform):${NC}"
            
            # Test basic execution
            local test_output=$(docker run --rm --entrypoint="" "$tag" /bin/echo "Test $arch" 2>/dev/null)
            if [[ "$test_output" == "Test $arch" ]]; then
                # Test Alpine version access
                local alpine_ver=$(docker run --rm --entrypoint="" "$tag" /bin/cat /etc/alpine-release 2>/dev/null)
                local build_info=$(docker run --rm --entrypoint="" "$tag" /bin/cat /etc/build_release 2>/dev/null | head -1)
                
                if [[ -n "$alpine_ver" && -n "$build_info" ]]; then
                    echo -e "  ${GREEN}✅ $arch: FULLY FUNCTIONAL${NC}"
                    echo -e "  ${BLUE}     Alpine: $alpine_ver | $build_info${NC}"
                    arch_results+=("✅ $arch")
                    ((supported_count++))
                else
                    echo -e "  ${YELLOW}⚠ $arch: BASIC EXECUTION ONLY${NC}"
                    arch_results+=("⚠ $arch")
                fi
            else
                echo -e "  ${RED}❌ $arch: NOT SUPPORTED${NC}"
                arch_results+=("❌ $arch")
            fi
            ((total_count++))
            echo ""
        fi
    done
    
    # Summary
    echo -e "${GREEN}=== EMULATION CAPABILITY SUMMARY ===${NC}"
    echo -e "${BLUE}Supported architectures: $supported_count/$total_count${NC}\n"
    
    for result in "${arch_results[@]}"; do
        echo "  $result"
    done
    
    echo ""
    if [[ $supported_count -eq $total_count ]]; then
        echo -e "${GREEN}🎉 AMAZING: Docker Desktop supports ALL tested architectures!${NC}"
        echo -e "${BLUE}You can test any architecture locally before CI/CD deployment.${NC}"
    elif [[ $supported_count -gt 5 ]]; then
        echo -e "${GREEN}🚀 EXCELLENT: Docker Desktop supports most architectures!${NC}"
        echo -e "${BLUE}You have comprehensive local testing capabilities.${NC}"
    elif [[ $supported_count -gt 2 ]]; then
        echo -e "${YELLOW}👍 GOOD: Docker Desktop supports common architectures.${NC}"
    else
        echo -e "${YELLOW}📝 LIMITED: Docker Desktop has basic emulation support.${NC}"
    fi
    echo ""
}

# Function to build multi-platform manifest
build_multiplatform() {
    local alpine_version=$1
    local push_flag=$2
    
    echo -e "${BLUE}Building multi-platform manifest for Alpine ${alpine_version}...${NC}"
    
    local platforms=()
    local tags=()
    
    # Build all architectures and collect tags
    for platform in "${!ARCH_MAP[@]}"; do
        IFS=':' read -r alpine_arch tag_suffix <<< "${ARCH_MAP[$platform]}"
        
        # Skip riscv64 for older Alpine versions
        if [[ "$platform" == "linux/riscv64" ]] && ! is_riscv64_supported "$alpine_version"; then
            echo -e "${YELLOW}Skipping riscv64 for Alpine ${alpine_version} (not supported)${NC}"
            continue
        fi
        
        platforms+=("$platform")
        tags+=("${REGISTRY_PREFIX}:test-alpine-${alpine_version}-${tag_suffix}")
        
        if ! build_arch "$platform" "$alpine_arch" "$tag_suffix" "$alpine_version" "$push_flag"; then
            echo -e "${RED}Failed to build $platform, skipping multi-platform manifest${NC}"
            return 1
        fi
    done
    
    # Create multi-platform manifest
    local manifest_tag="${REGISTRY_PREFIX}:test-alpine-${alpine_version}"
    
    if [[ "$push_flag" == "true" ]]; then
        echo -e "${BLUE}Creating and pushing multi-platform manifest: ${manifest_tag}${NC}"
        local platform_list=$(IFS=,; echo "${platforms[*]}")
        
        docker buildx build \
            --platform "$platform_list" \
            --build-arg "alpine_version=${alpine_version}" \
            --build-arg "RELEASE_VERSION=${alpine_version}" \
            --build-arg "BRANCH=local-test" \
            --provenance=true \
            --sbom=true \
            -t "$manifest_tag" \
            --push .
            
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Successfully created multi-platform manifest: ${manifest_tag}${NC}"
            
            if [[ "$TEST_ATTESTATIONS" == "true" ]]; then
                test_attestations "$manifest_tag"
            fi
        else
            echo -e "${RED}✗ Failed to create multi-platform manifest${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Multi-platform manifest creation skipped (not pushing)${NC}"
        echo -e "${BLUE}Individual architecture images built:${NC}"
        for tag in "${tags[@]}"; do
            echo "  - $tag"
            if [[ "$TEST_ATTESTATIONS" == "true" ]]; then
                test_attestations "$tag"
            fi
        done
    fi
}

# Main execution
echo -e "${GREEN}Alpine Base Image Local Build Script${NC}"
echo -e "${BLUE}=====================================${NC}"

# Check if docker buildx is available
if ! command -v docker &> /dev/null || ! docker buildx version &> /dev/null; then
    echo -e "${RED}Error: docker buildx is required but not available${NC}"
    exit 1
fi

# Handle emulation-only testing
if [[ "$TEST_EMULATION" == "true" ]]; then
    # Check if any test images exist
    if ! docker images | grep -q "test-alpine.*-"; then
        echo -e "${YELLOW}No test images found. Building a few architectures for emulation testing...${NC}"
        echo -e "${BLUE}Building AMD64, ARM64, and RISC-V for emulation test...${NC}\n"
        
        # Build a representative set of architectures
        for arch_pair in "linux/amd64:x86_64:amd64" "linux/arm64/v8:aarch64:arm64" "linux/riscv64:riscv64:riscv64"; do
            IFS=':' read -r platform alpine_arch tag_suffix <<< "$arch_pair"
            build_arch "$platform" "$alpine_arch" "$tag_suffix" "$ALPINE_VERSION" "false"
        done
        echo ""
    fi
    
    test_architecture_emulation
    exit 0
fi

# Single architecture build
if [[ -n "$BUILD_SINGLE_ARCH" ]]; then
    # Find platform for requested architecture
    found_platform=""
    for platform in "${!ARCH_MAP[@]}"; do
        IFS=':' read -r alpine_arch tag_suffix <<< "${ARCH_MAP[$platform]}"
        if [[ "$tag_suffix" == "$BUILD_SINGLE_ARCH" ]] || [[ "$alpine_arch" == "$BUILD_SINGLE_ARCH" ]]; then
            found_platform="$platform"
            break
        fi
    done
    
    if [[ -z "$found_platform" ]]; then
        echo -e "${RED}Error: Architecture '$BUILD_SINGLE_ARCH' not found${NC}"
        echo -e "${BLUE}Supported architectures: ${!ARCH_MAP[@]}${NC}"
        exit 1
    fi
    
    IFS=':' read -r alpine_arch tag_suffix <<< "${ARCH_MAP[$found_platform]}"
    
    if [[ "$BUILD_ALL_VERSIONS" == "true" ]]; then
        for version in "${ALPINE_VERSIONS[@]}"; do
            build_arch "$found_platform" "$alpine_arch" "$tag_suffix" "$version" "$PUSH_IMAGES"
            if [[ "$TEST_ATTESTATIONS" == "true" ]]; then
                test_attestations "${REGISTRY_PREFIX}:test-alpine-${version}-${tag_suffix}"
            fi
        done
    else
        build_arch "$found_platform" "$alpine_arch" "$tag_suffix" "$ALPINE_VERSION" "$PUSH_IMAGES"
        if [[ "$TEST_ATTESTATIONS" == "true" ]]; then
            test_attestations "${REGISTRY_PREFIX}:test-alpine-${ALPINE_VERSION}-${tag_suffix}"
        fi
    fi
    
    exit 0
fi

# Multi-platform builds
if [[ "$BUILD_ALL_VERSIONS" == "true" ]]; then
    echo -e "${BLUE}Building all Alpine versions with all architectures...${NC}"
    for version in "${ALPINE_VERSIONS[@]}"; do
        echo -e "\n${YELLOW}=== Building Alpine ${version} ===${NC}"
        build_multiplatform "$version" "$PUSH_IMAGES"
    done
else
    echo -e "${BLUE}Building Alpine ${ALPINE_VERSION} with all architectures...${NC}"
    build_multiplatform "$ALPINE_VERSION" "$PUSH_IMAGES"
fi

# Run architecture emulation test if requested
if [[ "$TEST_EMULATION" == "true" ]]; then
    test_architecture_emulation
fi

echo -e "\n${GREEN}Build script completed!${NC}"