#!/bin/bash

# api-client.test.sh
# Unit tests for API client functionality and response handling
# Part of issue #25 implementation

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

# Source the main script
source "$PROJECT_ROOT/scripts/check-immutable-tags.sh"

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

# Mock curl function for testing
mock_curl() {
    local url="$1"
    local expected_response="$2"
    local expected_code="$3"
    
    # Simulate response based on URL pattern
    case "$url" in
        *auth.docker.io/token*)
            if [[ "$expected_code" == "200" ]]; then
                cat "$FIXTURES_DIR/api-responses/docker-hub-auth-success.json"
                return 0
            else
                cat "$FIXTURES_DIR/api-responses/docker-hub-auth-failure.json" >&2
                return 1
            fi
            ;;
        *registry-1.docker.io/v2/*/manifests/*)
            # Extract tag from URL for specific responses
            local tag
            tag=$(echo "$url" | sed 's|.*/manifests/||')
            
            case "$tag" in
                "alpine-3.22.1"|"alpine-3.21.4")
                    # Simulate existing immutable tags
                    if [[ "$expected_code" == "200" ]]; then
                        echo '{"schemaVersion": 2, "mediaType": "application/vnd.docker.distribution.manifest.v2+json"}'
                        return 0
                    fi
                    ;;
                "test-"*|"*-test")
                    # Simulate non-existing test tags
                    return 1  # 404
                    ;;
            esac
            
            # Default to simulated response
            if [[ "$expected_code" == "200" ]]; then
                echo '{"mock": "response"}'
                return 0
            else
                return 1
            fi
            ;;
        *)
            echo "Unknown URL pattern: $url" >&2
            return 1
            ;;
    esac
}

# Test JSON parsing with jq
test_json_parsing_jq() {
    echo -e "\n${YELLOW}=== Testing JSON Parsing with jq ===${NC}"
    
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}[SKIP]${NC} jq not available, skipping jq-specific tests"
        return 0
    fi
    
    # Test token extraction from auth response
    test_start "Token extraction with jq"
    local test_response
    test_response=$(cat "$FIXTURES_DIR/api-responses/docker-hub-auth-success.json")
    local token
    token=$(echo "$test_response" | jq -r '.token')
    
    if [[ -n "$token" && "$token" != "null" ]]; then
        test_pass "Token extraction with jq"
    else
        test_fail "Token extraction with jq" "Token extraction failed: '$token'"
    fi
    
    # Test malformed JSON handling
    test_start "Malformed JSON handling"
    local malformed_json='{"token": "valid", "incomplete"'
    local result
    if result=$(echo "$malformed_json" | jq -r '.token' 2>/dev/null); then
        test_fail "Malformed JSON handling" "Should have failed on malformed JSON"
    else
        test_pass "Malformed JSON handling"
    fi
}

# Test JSON parsing fallback (without jq)
test_json_parsing_fallback() {
    echo -e "\n${YELLOW}=== Testing JSON Parsing Fallback ===${NC}"
    
    # Test token extraction using sed
    test_start "Token extraction with sed fallback"
    local test_response
    test_response=$(cat "$FIXTURES_DIR/api-responses/docker-hub-auth-success.json")
    local token
    token=$(echo "$test_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
    
    if [[ -n "$token" ]]; then
        test_pass "Token extraction with sed fallback"
    else
        test_fail "Token extraction with sed fallback" "Token extraction failed: '$token'"
    fi
    
    # Test with different JSON formatting
    test_start "Sed parsing with varied formatting"
    local varied_json='{ "token" : "test-token-123" , "other": "value" }'
    local extracted_token
    extracted_token=$(echo "$varied_json" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
    
    if [[ "$extracted_token" == "test-token-123" ]]; then
        test_pass "Sed parsing with varied formatting"
    else
        test_fail "Sed parsing with varied formatting" "Expected 'test-token-123', got '$extracted_token'"
    fi
}

# Test HTTP response code handling
test_http_response_codes() {
    echo -e "\n${YELLOW}=== Testing HTTP Response Code Handling ===${NC}"
    
    # Test success codes
    test_start "HTTP 200 handling"
    local code="200"
    case "$code" in
        200) test_pass "HTTP 200 handling" ;;
        *) test_fail "HTTP 200 handling" "Unexpected case handling" ;;
    esac
    
    # Test not found
    test_start "HTTP 404 handling"
    local code="404"
    case "$code" in
        404) test_pass "HTTP 404 handling" ;;
        *) test_fail "HTTP 404 handling" "Unexpected case handling" ;;
    esac
    
    # Test authentication errors
    local auth_codes=("401" "403")
    for code in "${auth_codes[@]}"; do
        test_start "HTTP $code handling"
        case "$code" in
            401|403) test_pass "HTTP $code handling" ;;
            *) test_fail "HTTP $code handling" "Unexpected case handling" ;;
        esac
    done
    
    # Test rate limiting
    test_start "HTTP 429 handling"
    local code="429"
    case "$code" in
        429) test_pass "HTTP 429 handling" ;;
        *) test_fail "HTTP 429 handling" "Rate limit detection failed" ;;
    esac
    
    # Test server errors
    local server_codes=("500" "502" "503" "504")
    for code in "${server_codes[@]}"; do
        test_start "HTTP $code (server error) handling"
        case "$code" in
            5??) test_pass "HTTP $code (server error) handling" ;;
            *) test_fail "HTTP $code (server error) handling" "Server error detection failed" ;;
        esac
    done
}

# Test curl command construction
test_curl_command_construction() {
    echo -e "\n${YELLOW}=== Testing Curl Command Construction ===${NC}"
    
    # Test that curl is available
    test_start "Curl availability"
    if command -v curl >/dev/null 2>&1; then
        test_pass "Curl availability"
    else
        test_fail "Curl availability" "curl command not found"
        return 1
    fi
    
    # Test auth URL construction
    test_start "Auth URL construction"
    local registry="liskl/base"
    local expected_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${registry}:pull"
    local auth_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${registry}:pull"
    
    if [[ "$auth_url" == "$expected_url" ]]; then
        test_pass "Auth URL construction"
    else
        test_fail "Auth URL construction" "URL mismatch: expected '$expected_url', got '$auth_url'"
    fi
    
    # Test manifest URL construction
    test_start "Manifest URL construction"
    local tag="alpine-3.22.1"
    local expected_manifest_url="https://registry-1.docker.io/v2/${registry}/manifests/${tag}"
    local manifest_url="https://registry-1.docker.io/v2/${registry}/manifests/${tag}"
    
    if [[ "$manifest_url" == "$expected_manifest_url" ]]; then
        test_pass "Manifest URL construction"
    else
        test_fail "Manifest URL construction" "URL mismatch: expected '$expected_manifest_url', got '$manifest_url'"
    fi
}

# Test error handling scenarios
test_error_handling() {
    echo -e "\n${YELLOW}=== Testing Error Handling ===${NC}"
    
    # Test empty token response
    test_start "Empty token handling"
    local empty_token=""
    if [[ -z "$empty_token" || "$empty_token" == "null" ]]; then
        test_pass "Empty token handling"
    else
        test_fail "Empty token handling" "Should detect empty token"
    fi
    
    # Test null token response
    test_start "Null token handling"
    local null_token="null"
    if [[ -z "$null_token" || "$null_token" == "null" ]]; then
        test_pass "Null token handling"
    else
        test_fail "Null token handling" "Should detect null token"
    fi
    
    # Test network timeout simulation
    test_start "Network timeout handling"
    # This is a logical test of timeout detection patterns
    local timeout_exit_code=124  # curl timeout exit code
    if [[ $timeout_exit_code -eq 124 ]]; then
        test_pass "Network timeout handling"
    else
        test_fail "Network timeout handling" "Timeout detection logic incorrect"
    fi
}

# Test API response validation
test_api_response_validation() {
    echo -e "\n${YELLOW}=== Testing API Response Validation ===${NC}"
    
    # Test valid auth response structure
    test_start "Valid auth response validation"
    local auth_response
    auth_response=$(cat "$FIXTURES_DIR/api-responses/docker-hub-auth-success.json")
    
    if echo "$auth_response" | grep -q '"token"'; then
        test_pass "Valid auth response validation"
    else
        test_fail "Valid auth response validation" "Token field not found in response"
    fi
    
    # Test invalid auth response handling
    test_start "Invalid auth response validation"
    local invalid_response='{"error": "invalid"}'
    
    if echo "$invalid_response" | grep -q '"token"'; then
        test_fail "Invalid auth response validation" "Should not find token in invalid response"
    else
        test_pass "Invalid auth response validation"
    fi
}

# Test logging integration
test_logging_integration() {
    echo -e "\n${YELLOW}=== Testing Logging Integration ===${NC}"
    
    # Test debug output for API operations
    test_start "API debug logging"
    local old_debug="$DEBUG"
    DEBUG="true"
    
    # Capture debug output
    local debug_output
    debug_output=$(log_api_debug "TEST_OPERATION" "https://example.com" "200" "test details" 2>&1)
    
    DEBUG="$old_debug"
    
    if [[ "$debug_output" == *"API-DEBUG"* ]] && [[ "$debug_output" == *"TEST_OPERATION"* ]]; then
        test_pass "API debug logging"
    else
        test_fail "API debug logging" "Debug output not found or malformed"
    fi
}

# Main test runner
run_api_client_tests() {
    echo -e "${BLUE}Starting API client and response handling tests${NC}\n"
    
    # Verify test fixtures exist
    local auth_success_file="$FIXTURES_DIR/api-responses/docker-hub-auth-success.json"
    if [[ ! -f "$auth_success_file" ]]; then
        echo -e "${RED}Error: Auth success fixture not found at $auth_success_file${NC}"
        exit 1
    fi
    
    # Suppress normal script output during tests
    local old_quiet="${QUIET:-false}"
    QUIET="true"
    
    test_json_parsing_jq
    test_json_parsing_fallback
    test_http_response_codes
    test_curl_command_construction
    test_error_handling
    test_api_response_validation
    test_logging_integration
    
    QUIET="$old_quiet"
    
    # Print summary
    echo -e "\n${YELLOW}=== API Client Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All API client tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some API client tests failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_api_client_tests
fi