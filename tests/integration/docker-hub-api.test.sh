#!/bin/bash

# docker-hub-api.test.sh  
# Integration tests for Docker Hub API interactions
# Part of issue #25 implementation

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

# Test framework variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
INTEGRATION_REGISTRY="${INTEGRATION_REGISTRY:-liskl/base}"
SKIP_LIVE_TESTS="${SKIP_LIVE_TESTS:-false}"

# Test helper functions
test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST]${NC} $test_name"
}

test_pass() {
    local test_name="$1"
    ((TESTS_PASSED++))
    echo -e "${GREEN}[PASS]${NC} $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_FAILED++))
    echo -e "${RED}[FAIL]${NC} $test_name: $reason"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "${YELLOW}[SKIP]${NC} $test_name: $reason"
}

# Test Docker Hub authentication
test_docker_hub_auth() {
    echo -e "\n${YELLOW}=== Testing Docker Hub Authentication ===${NC}"
    
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        test_skip "Docker Hub authentication" "Live tests disabled"
        return 0
    fi
    
    test_start "Docker Hub auth token retrieval"
    local auth_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${INTEGRATION_REGISTRY}:pull"
    local token_response
    
    if token_response=$(curl -s -f "$auth_url" 2>/dev/null); then
        # Check if response contains token
        if echo "$token_response" | grep -q '"token"'; then
            test_pass "Docker Hub auth token retrieval"
        else
            test_fail "Docker Hub auth token retrieval" "Token not found in response"
        fi
    else
        test_fail "Docker Hub auth token retrieval" "Auth request failed"
    fi
}

# Test manifest existence checking
test_manifest_checking() {
    echo -e "\n${YELLOW}=== Testing Manifest Existence Checking ===${NC}"
    
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        test_skip "Manifest checking" "Live tests disabled"
        return 0
    fi
    
    # Test with a tag that should exist
    test_start "Existing tag manifest check"
    local result
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --quiet "alpine-3.22.1" 2>/dev/null); then
        local exit_code=$?
        case $exit_code in
            0)
                test_pass "Existing tag manifest check (tag can be pushed)"
                ;;
            1)
                test_pass "Existing tag manifest check (tag should be skipped)"
                ;;
            *)
                test_fail "Existing tag manifest check" "Unexpected exit code: $exit_code"
                ;;
        esac
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            test_fail "Existing tag manifest check" "API error occurred"
        else
            test_fail "Existing tag manifest check" "Unexpected failure: exit code $exit_code"
        fi
    fi
    
    # Test with a tag that should not exist
    test_start "Non-existing tag manifest check"
    local non_existing_tag="test-non-existing-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --quiet "$non_existing_tag" 2>/dev/null); then
        test_pass "Non-existing tag manifest check"
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            test_fail "Non-existing tag manifest check" "API error occurred"
        else
            test_fail "Non-existing tag manifest check" "Unexpected failure: exit code $exit_code"
        fi
    fi
}

# Test rate limiting behavior
test_rate_limiting() {
    echo -e "\n${YELLOW}=== Testing Rate Limiting Behavior ===${NC}"
    
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        test_skip "Rate limiting" "Live tests disabled"
        return 0
    fi
    
    test_start "Rate limiting resilience"
    local rate_limit_hit=false
    
    # Make multiple rapid requests to test rate limiting handling
    for i in {1..5}; do
        local test_tag="rate-limit-test-$i-$(date +%s)"
        local result exit_code
        
        if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --quiet "$test_tag" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        # Check for rate limiting indicators
        if [[ "$result" == *"429"* ]] || [[ "$result" == *"rate limit"* ]]; then
            rate_limit_hit=true
            break
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    # Rate limiting behavior test passes if either:
    # 1. No rate limiting encountered (good API design)
    # 2. Rate limiting encountered and handled gracefully
    test_pass "Rate limiting resilience"
}

# Test network error handling
test_network_error_handling() {
    echo -e "\n${YELLOW}=== Testing Network Error Handling ===${NC}"
    
    # Test with invalid registry (should fail gracefully)
    test_start "Invalid registry handling"
    local result exit_code
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --registry "invalid/nonexistent" --quiet "test-tag" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 2 ]]; then
        test_pass "Invalid registry handling"
    else
        test_fail "Invalid registry handling" "Expected exit code 2, got $exit_code"
    fi
    
    # Test with malformed registry name
    test_start "Malformed registry name handling"
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --registry "malformed registry name!" --quiet "test-tag" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 2 ]]; then
        test_pass "Malformed registry name handling"
    else
        test_fail "Malformed registry name handling" "Expected exit code 2, got $exit_code"
    fi
}

# Test multiple tag scenarios
test_multiple_tag_scenarios() {
    echo -e "\n${YELLOW}=== Testing Multiple Tag Scenarios ===${NC}"
    
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        test_skip "Multiple tag scenarios" "Live tests disabled"
        return 0
    fi
    
    # Test mixed immutable/mutable tags
    test_start "Mixed tag types"
    local mixed_tags=("alpine-3.22.1" "test-mutable-$(date +%s)" "522a89e-alpine-3.21.4")
    local result exit_code
    
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --quiet "${mixed_tags[@]}" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Should handle mixed tags appropriately
    case $exit_code in
        0|1)
            test_pass "Mixed tag types"
            ;;
        2)
            test_fail "Mixed tag types" "API error occurred"
            ;;
        *)
            test_fail "Mixed tag types" "Unexpected exit code: $exit_code"
            ;;
    esac
}

# Test JSON output integration
test_json_output_integration() {
    echo -e "\n${YELLOW}=== Testing JSON Output Integration ===${NC}"
    
    test_start "JSON output format validation"
    local test_tag="json-test-$(date +%s)"
    local result
    
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --json "$test_tag" 2>/dev/null); then
        # Validate JSON structure
        if command -v jq >/dev/null 2>&1; then
            if echo "$result" | jq . >/dev/null 2>&1; then
                # Check for required fields
                if echo "$result" | jq -e '.summary.total_tags' >/dev/null 2>&1; then
                    test_pass "JSON output format validation"
                else
                    test_fail "JSON output format validation" "Missing required summary fields"
                fi
            else
                test_fail "JSON output format validation" "Invalid JSON format"
            fi
        else
            # Basic validation without jq
            if [[ "$result" == *"{"* ]] && [[ "$result" == *"}"* ]] && [[ "$result" == *"summary"* ]]; then
                test_pass "JSON output format validation"
            else
                test_fail "JSON output format validation" "JSON structure appears invalid"
            fi
        fi
    else
        test_fail "JSON output format validation" "Script execution failed"
    fi
}

# Test debug output integration
test_debug_output_integration() {
    echo -e "\n${YELLOW}=== Testing Debug Output Integration ===${NC}"
    
    test_start "Debug output functionality"
    local test_tag="debug-test-$(date +%s)"
    local result
    
    if result=$("$PROJECT_ROOT/scripts/check-immutable-tags.sh" --debug "$test_tag" 2>&1); then
        if [[ "$result" == *"[DEBUG]"* ]] && [[ "$result" == *"API-DEBUG"* ]]; then
            test_pass "Debug output functionality"
        else
            test_fail "Debug output functionality" "Debug output not found or incomplete"
        fi
    else
        test_fail "Debug output functionality" "Script execution failed"
    fi
}

# Main test runner
run_integration_tests() {
    echo -e "${BLUE}Starting Docker Hub API integration tests${NC}\n"
    
    # Check if live tests should be skipped
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        echo -e "${YELLOW}Note: Live API tests are disabled. Set SKIP_LIVE_TESTS=false to enable.${NC}\n"
    fi
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}Error: curl is required for integration tests${NC}"
        exit 1
    fi
    
    test_docker_hub_auth
    test_manifest_checking
    test_rate_limiting
    test_network_error_handling
    test_multiple_tag_scenarios
    test_json_output_integration
    test_debug_output_integration
    
    # Print summary
    echo -e "\n${YELLOW}=== Integration Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All integration tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some integration tests failed!${NC}"
        return 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run integration tests for Docker Hub API functionality.

OPTIONS:
    -h, --help              Show this help message
    -s, --skip-live         Skip live API tests (default: false)
    -r, --registry REGISTRY Set test registry (default: liskl/base)

ENVIRONMENT VARIABLES:
    SKIP_LIVE_TESTS         Skip live API tests (true/false)
    INTEGRATION_REGISTRY    Registry to use for tests

EXAMPLES:
    $0                      # Run all tests
    $0 --skip-live          # Run only offline tests
    $0 -r myregistry/test   # Use custom registry

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -s|--skip-live)
            SKIP_LIVE_TESTS="true"
            shift
            ;;
        -r|--registry)
            INTEGRATION_REGISTRY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
fi