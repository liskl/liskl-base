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

# GitHub Actions detection
GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"

# Logging functions with GitHub Actions annotations support
log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

log_info() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${GREEN}[INFO]${NC} $*" >&2
        if [[ "$GITHUB_ACTIONS" == "true" ]]; then
            echo "::notice::$*"
        fi
    fi
}

log_warn() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $*" >&2
        if [[ "$GITHUB_ACTIONS" == "true" ]]; then
            echo "::warning::$*"
        fi
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::error::$*"
    fi
}

# GitHub Actions grouping functions
log_group_start() {
    local title="$1"
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::group::$title"
    else
        log_info "=== $title ==="
    fi
}

log_group_end() {
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::endgroup::"
    fi
}

# Enhanced debug logging for API operations
log_api_debug() {
    local operation="$1"
    local url="$2"
    local response_code="${3:-unknown}"
    local details="${4:-}"
    
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[API-DEBUG]${NC} $operation: $url (HTTP $response_code)" >&2
        if [[ -n "$details" ]]; then
            echo -e "${BLUE}[API-DEBUG]${NC} Details: $details" >&2
        fi
    fi
}

# Structured logging for tag analysis
log_tag_analysis() {
    local tag="$1"
    local is_immutable="$2"
    local exists="$3"
    local decision="$4"
    local reason="${5:-}"
    
    local message="Tag analysis: $tag | Immutable: $is_immutable | Exists: $exists | Decision: $decision"
    if [[ -n "$reason" ]]; then
        message="$message | Reason: $reason"
    fi
    
    case "$decision" in
        "SKIP")
            log_warn "$message"
            ;;
        "PUSH")
            log_info "$message"
            ;;
        "ERROR")
            log_error "$message"
            ;;
        *)
            log_debug "$message"
            ;;
    esac
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
    
    log_api_debug "AUTH_REQUEST" "$auth_url" "pending" "Requesting Docker Hub authentication token"
    
    if ! token_response=$(curl -s -f "$auth_url" 2>/dev/null); then
        log_api_debug "AUTH_REQUEST" "$auth_url" "failed" "Could not retrieve authentication token"
        log_error "Failed to get authentication token from Docker Hub for $registry:$tag"
        return 2  # API error
    fi
    
    log_api_debug "AUTH_REQUEST" "$auth_url" "200" "Authentication token received successfully"
    
    local token
    if command -v jq >/dev/null 2>&1; then
        token=$(echo "$token_response" | jq -r '.token')
        log_debug "Token extracted using jq"
    else
        # Fallback parsing without jq
        token=$(echo "$token_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
        log_debug "Token extracted using sed fallback (jq not available)"
    fi
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_api_debug "AUTH_PARSE" "$auth_url" "error" "Token extraction failed from response"
        log_error "Failed to extract token from Docker Hub auth response for $registry:$tag"
        return 2
    fi
    
    log_debug "Successfully obtained and parsed auth token"
    
    # Step 2: Check if the tag exists using the manifest endpoint
    local manifest_url="https://registry-1.docker.io/v2/${registry}/manifests/${tag}"
    local response_code
    
    log_api_debug "MANIFEST_CHECK" "$manifest_url" "pending" "Checking if manifest exists"
    
    # Use HEAD request to check if manifest exists (more efficient)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "$manifest_url" 2>/dev/null)
    
    log_api_debug "MANIFEST_CHECK" "$manifest_url" "$response_code" "Manifest check completed"
    
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
            log_error "Authentication failed or access denied for $registry:$tag (HTTP $response_code)"
            return 2
            ;;
        429)
            log_warn "Rate limit exceeded for Docker Hub API (HTTP $response_code)"
            return 2
            ;;
        5??)
            log_error "Docker Hub server error (HTTP $response_code) for $registry:$tag"
            return 2
            ;;
        *)
            log_error "Unexpected HTTP response code: $response_code for $registry:$tag"
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
        log_debug "Tag '$tag' matches immutable pattern"
    else
        log_debug "Tag '$tag' does not match immutable pattern"
    fi
    
    # Check if tag exists (only if it matches immutable pattern)
    local exists="false"
    local should_skip="false"
    local api_error="false"
    local decision=""
    local reason=""
    
    if [[ "$is_immutable" == "true" ]]; then
        case $(tag_exists_on_dockerhub "$registry" "$tag"; echo $?) in
            0)
                exists="true"
                should_skip="true"
                decision="SKIP"
                reason="immutable tag exists on Docker Hub"
                log_tag_analysis "$tag" "$is_immutable" "$exists" "$decision" "$reason"
                ;;
            1)
                exists="false"
                should_skip="false"
                decision="PUSH"
                reason="immutable tag doesn't exist yet"
                log_tag_analysis "$tag" "$is_immutable" "$exists" "$decision" "$reason"
                ;;
            2)
                api_error="true"
                decision="ERROR"
                reason="Docker Hub API failure"
                log_tag_analysis "$tag" "$is_immutable" "unknown" "$decision" "$reason"
                ;;
        esac
    else
        decision="PUSH"
        reason="mutable tag pattern"
        log_tag_analysis "$tag" "$is_immutable" "n/a" "$decision" "$reason"
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
    "api_error": $api_error,
    "decision": "$decision",
    "reason": "$reason"
}
EOF
        )
    else
        case "$decision" in
            "SKIP")
                result="SKIP $registry:$tag ($reason)"
                ;;
            "ERROR")
                result="ERROR $registry:$tag ($reason)"
                ;;
            "PUSH")
                result="PUSH $registry:$tag ($reason)"
                ;;
            *)
                result="UNKNOWN $registry:$tag"
                ;;
        esac
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
    log_debug "GitHub Actions mode: $GITHUB_ACTIONS"
    
    # Start grouped logging for tag checking
    log_group_start "Immutable Tag Analysis for $registry"
    log_info "Analyzing ${#tags[@]} tag(s) for immutability and Docker Hub existence"
    
    # Check each tag
    local results=()
    local overall_exit_code=0
    local has_api_errors=false
    local has_skips=false
    local push_count=0
    local skip_count=0
    local error_count=0
    
    for tag in "${tags[@]}"; do
        local result
        local exit_code
        
        # Capture result even if function returns non-zero exit code
        if result=$(check_tag "$registry" "$tag"); then
            exit_code=0
            push_count=$((push_count + 1))
        else
            exit_code=$?
        fi
        
        results+=("$result")
        
        case $exit_code in
            1)
                has_skips=true
                skip_count=$((skip_count + 1))
                ;;
            2)
                has_api_errors=true
                error_count=$((error_count + 1))
                ;;
        esac
    done
    
    log_group_end
    
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
        echo "    \"push_count\": $push_count,"
        echo "    \"skip_count\": $skip_count,"
        echo "    \"error_count\": $error_count,"
        echo "    \"has_skips\": $has_skips,"
        echo "    \"has_api_errors\": $has_api_errors"
        echo "  }"
        echo "}"
    else
        for result in "${results[@]}"; do
            echo "$result"
        done
        
        # Enhanced summary with counts
        log_group_start "Analysis Summary"
        log_info "Tag analysis complete: $push_count push, $skip_count skip, $error_count error (total: ${#tags[@]})"
        
        if [[ "$push_count" -gt 0 ]]; then
            log_info "✓ $push_count tag(s) are safe to push"
        fi
        
        if [[ "$skip_count" -gt 0 ]]; then
            log_warn "⚠ $skip_count tag(s) should be skipped (immutable and exist)"
        fi
        
        if [[ "$error_count" -gt 0 ]]; then
            log_error "✗ $error_count tag(s) had API errors during checking"
        fi
        
        # Set GitHub Actions outputs for workflow integration
        if [[ "$GITHUB_ACTIONS" == "true" ]]; then
            echo "push_count=$push_count" >> "$GITHUB_OUTPUT"
            echo "skip_count=$skip_count" >> "$GITHUB_OUTPUT"
            echo "error_count=$error_count" >> "$GITHUB_OUTPUT"
            echo "has_skips=$has_skips" >> "$GITHUB_OUTPUT"
            echo "has_api_errors=$has_api_errors" >> "$GITHUB_OUTPUT"
            log_debug "GitHub Actions outputs set for downstream workflow steps"
        fi
        
        log_group_end
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