#!/bin/bash

# check-immutable-tags.sh
# Detects immutable Docker Hub tags to prevent push failures
# Part of issue #22 implementation

set -euo pipefail

# Configuration
REGISTRY_BASE="liskl/base"
IMMUTABLE_PATTERN="^alpine-[0-9]+\.[0-9]+\.[0-9]+$"
DEBUG="${DEBUG:-false}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] TAG [TAG...]

Check if Docker tags match immutable pattern and exist on Docker Hub.

OPTIONS:
    -h, --help              Show this help message
    -r, --registry REGISTRY Registry prefix (default: $REGISTRY_BASE)
    -j, --json              Output in JSON format
    -d, --debug             Enable debug output
    -q, --quiet             Suppress info output (errors only)

EXAMPLES:
    $0 alpine-3.22.1
    $0 -j alpine-3.22.1 alpine-3.21.4
    $0 -r myregistry/base alpine-3.22.1
    OUTPUT_FORMAT=json $0 alpine-3.22.1

EXIT CODES:
    0  All tags are safe to push (not immutable or don't exist)
    1  One or more tags are immutable and exist (should not push)
    2  Error in execution (API failure, invalid input, etc.)
EOF
}

# Logging functions
log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

log_info() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${GREEN}[INFO]${NC} $*" >&2
    fi
}

log_warn() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $*" >&2
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if tag matches immutable pattern
is_immutable_pattern() {
    local tag="$1"
    log_debug "Checking pattern for tag: $tag"
    
    if [[ "$tag" =~ $IMMUTABLE_PATTERN ]]; then
        log_debug "Tag '$tag' matches immutable pattern"
        return 0
    else
        log_debug "Tag '$tag' does not match immutable pattern"
        return 1
    fi
}

# Check if tag exists on Docker Hub using registry API
tag_exists_on_dockerhub() {
    local registry="$1"
    local tag="$2"
    
    log_debug "Checking if tag exists: $registry:$tag"
    
    # Step 1: Get authentication token from Docker Hub
    local auth_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${registry}:pull"
    local token_response
    
    log_debug "Getting auth token from: $auth_url"
    
    if ! token_response=$(curl -s -f "$auth_url" 2>/dev/null); then
        log_debug "Failed to get authentication token from Docker Hub"
        return 2  # API error
    fi
    
    local token
    if command -v jq >/dev/null 2>&1; then
        token=$(echo "$token_response" | jq -r '.token')
    else
        # Fallback parsing without jq
        token=$(echo "$token_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
    fi
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_debug "Failed to extract token from auth response"
        return 2
    fi
    
    log_debug "Successfully obtained auth token"
    
    # Step 2: Check if the tag exists using the manifest endpoint
    local manifest_url="https://registry-1.docker.io/v2/${registry}/manifests/${tag}"
    local response_code
    
    log_debug "Checking manifest at: $manifest_url"
    
    # Use HEAD request to check if manifest exists (more efficient)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "$manifest_url" 2>/dev/null)
    
    log_debug "HTTP response code: $response_code"
    
    case "$response_code" in
        200)
            log_debug "Tag '$tag' exists on Docker Hub"
            return 0
            ;;
        404)
            log_debug "Tag '$tag' does not exist on Docker Hub"
            return 1
            ;;
        401|403)
            log_debug "Authentication failed or access denied"
            return 2
            ;;
        *)
            log_debug "Unexpected response code: $response_code"
            return 2
            ;;
    esac
}

# Check single tag
check_tag() {
    local registry="$1"
    local tag="$2"
    local result={}
    
    log_info "Checking tag: $registry:$tag"
    
    # Check if tag matches immutable pattern
    local is_immutable="false"
    if is_immutable_pattern "$tag"; then
        is_immutable="true"
    fi
    
    # Check if tag exists (only if it matches immutable pattern)
    local exists="false"
    local should_skip="false"
    local api_error="false"
    
    if [[ "$is_immutable" == "true" ]]; then
        case $(tag_exists_on_dockerhub "$registry" "$tag"; echo $?) in
            0)
                exists="true"
                should_skip="true"
                log_warn "Tag $registry:$tag is immutable and exists - should skip push"
                ;;
            1)
                exists="false"
                should_skip="false"
                log_info "Tag $registry:$tag is immutable but doesn't exist - can push"
                ;;
            2)
                api_error="true"
                log_error "API error checking tag $registry:$tag"
                ;;
        esac
    else
        log_info "Tag $registry:$tag is mutable - can push"
    fi
    
    # Build result object
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        result=$(cat << EOF
{
    "tag": "$tag",
    "registry": "$registry",
    "is_immutable_pattern": $is_immutable,
    "exists_on_dockerhub": $exists,
    "should_skip_push": $should_skip,
    "api_error": $api_error
}
EOF
        )
    else
        if [[ "$should_skip" == "true" ]]; then
            result="SKIP $registry:$tag (immutable and exists)"
        elif [[ "$api_error" == "true" ]]; then
            result="ERROR $registry:$tag (API failure)"
        else
            result="PUSH $registry:$tag"
        fi
    fi
    
    echo "$result"
    
    # Return appropriate exit code
    if [[ "$api_error" == "true" ]]; then
        return 2
    elif [[ "$should_skip" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

# Main function
main() {
    local registry="$REGISTRY_BASE"
    local tags=()
    local quiet="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--registry)
                registry="$2"
                shift 2
                ;;
            -j|--json)
                OUTPUT_FORMAT="json"
                shift
                ;;
            -d|--debug)
                DEBUG="true"
                shift
                ;;
            -q|--quiet)
                QUIET="true"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 2
                ;;
            *)
                tags+=("$1")
                shift
                ;;
        esac
    done
    
    # Check if tags provided
    if [[ ${#tags[@]} -eq 0 ]]; then
        log_error "No tags provided"
        usage
        exit 2
    fi
    
    log_debug "Registry: $registry"
    log_debug "Tags to check: ${tags[*]}"
    log_debug "Output format: $OUTPUT_FORMAT"
    
    # Check each tag
    local results=()
    local overall_exit_code=0
    local has_api_errors=false
    local has_skips=false
    
    for tag in "${tags[@]}"; do
        local result
        local exit_code
        
        # Capture result even if function returns non-zero exit code
        if result=$(check_tag "$registry" "$tag"); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        results+=("$result")
        
        case $exit_code in
            1)
                has_skips=true
                ;;
            2)
                has_api_errors=true
                ;;
        esac
    done
    
    # Output results
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{"
        echo "  \"registry\": \"$registry\","
        echo "  \"results\": ["
        for i in "${!results[@]}"; do
            echo "    ${results[$i]}"
            if [[ $i -lt $((${#results[@]} - 1)) ]]; then
                echo ","
            fi
        done
        echo "  ],"
        echo "  \"summary\": {"
        echo "    \"total_tags\": ${#tags[@]},"
        echo "    \"has_skips\": $has_skips,"
        echo "    \"has_api_errors\": $has_api_errors"
        echo "  }"
        echo "}"
    else
        for result in "${results[@]}"; do
            echo "$result"
        done
        
        # Summary
        if [[ "$has_skips" == "true" ]]; then
            log_warn "Some tags should be skipped due to immutability"
        fi
        if [[ "$has_api_errors" == "true" ]]; then
            log_error "Some API errors occurred"
        fi
    fi
    
    # Determine exit code
    if [[ "$has_api_errors" == "true" ]]; then
        exit 2
    elif [[ "$has_skips" == "true" ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi