#!/bin/bash

# test-check-immutable-tags.sh
# Unit tests for check-immutable-tags.sh
# Part of issue #22 implementation

set -euo pipefail

# Source the script to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/check-immutable-tags.sh"

# Test framework variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for test output
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

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Expected '$expected', got '$actual'"
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Expected true/0, got '$condition'"
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"
    
    if [[ "$condition" == "false" ]] || [[ "$condition" -ne 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Expected false/non-zero, got '$condition'"
    fi
}

# Test immutable pattern matching
test_immutable_pattern_matching() {
    echo -e "\n${YELLOW}=== Testing Immutable Pattern Matching ===${NC}"
    
    # Test cases that should match (immutable)
    local immutable_tags=(
        "alpine-3.22.1"
        "alpine-3.21.4"
        "alpine-3.20.7"
        "alpine-3.19.8"
        "alpine-3.18.12"
        "alpine-3.17.10"
        "alpine-3.16.9"
        "alpine-3.15.11"
        "alpine-3.14.3"
        "alpine-1.0.0"
        "alpine-99.99.99"
    )
    
    for tag in "${immutable_tags[@]}"; do
        test_start "Pattern match: $tag (should be immutable)"
        if is_immutable_pattern "$tag"; then
            test_pass "Pattern match: $tag (should be immutable)"
        else
            test_fail "Pattern match: $tag (should be immutable)" "Pattern did not match"
        fi
    done
    
    # Test cases that should NOT match (mutable)
    local mutable_tags=(
        "latest"
        "3e82e63-alpine-3.22.1"
        "522a89e-alpine-3.21.4"
        "alpine-3.22.1-dev"
        "alpine-3.22.1-rc1"
        "dev-alpine-3.22.1"
        "alpine-3.22"
        "alpine-3"
        "alpine"
        "alpine-3.22.1.1"
        "alpine-v3.22.1"
        "alpine-3.22.1a"
        "alpine-3.22.a"
        "alpine-a.22.1"
        ""
        "alpine-"
        "alpine-3.22.1-"
        "-alpine-3.22.1"
    )
    
    for tag in "${mutable_tags[@]}"; do
        test_start "Pattern match: '$tag' (should be mutable)"
        if is_immutable_pattern "$tag"; then
            test_fail "Pattern match: '$tag' (should be mutable)" "Pattern incorrectly matched"
        else
            test_pass "Pattern match: '$tag' (should be mutable)"
        fi
    done
}

# Test edge cases
test_edge_cases() {
    echo -e "\n${YELLOW}=== Testing Edge Cases ===${NC}"
    
    # Test with DEBUG enabled
    test_start "Debug mode functionality"
    local old_debug="$DEBUG"
    DEBUG="true"
    local output
    output=$(is_immutable_pattern "alpine-3.22.1" 2>&1)
    DEBUG="$old_debug"
    if [[ "$output" == *"DEBUG"* ]]; then
        test_pass "Debug mode functionality"
    else
        test_fail "Debug mode functionality" "No debug output found"
    fi
    
    # Test pattern with various number formats
    local version_formats=(
        "alpine-0.0.1"      # Single digits
        "alpine-10.20.30"   # Double digits
        "alpine-100.200.300" # Triple digits
    )
    
    for tag in "${version_formats[@]}"; do
        test_start "Version format: $tag"
        if is_immutable_pattern "$tag"; then
            test_pass "Version format: $tag"
        else
            test_fail "Version format: $tag" "Should match pattern"
        fi
    done
}

# Test script argument parsing (limited, since we need to avoid executing main)
test_argument_parsing() {
    echo -e "\n${YELLOW}=== Testing Argument Parsing ===${NC}"
    
    # Test help functionality
    test_start "Help option parsing"
    local help_output
    if help_output=$("$SCRIPT_DIR/check-immutable-tags.sh" --help 2>&1); then
        if [[ "$help_output" == *"Usage:"* ]]; then
            test_pass "Help option parsing"
        else
            test_fail "Help option parsing" "Help output malformed"
        fi
    else
        test_fail "Help option parsing" "Help option failed"
    fi
}

# Test JSON output format capability (without API calls)
test_json_functionality() {
    echo -e "\n${YELLOW}=== Testing JSON Functionality ===${NC}"
    
    # Test that jq is available (recommended for JSON parsing)
    test_start "jq availability check"
    if command -v jq >/dev/null 2>&1; then
        test_pass "jq availability check"
    else
        echo -e "${YELLOW}[WARN]${NC} jq not available - script will use grep fallback"
        test_pass "jq availability check (fallback mode)"
    fi
    
    # Test that curl is available (required for API calls)
    test_start "curl availability check"
    if command -v curl >/dev/null 2>&1; then
        test_pass "curl availability check"
    else
        test_fail "curl availability check" "curl is required for Docker Hub API calls"
    fi
}

# Integration test with actual script execution (safe tags only)
test_script_execution() {
    echo -e "\n${YELLOW}=== Testing Script Execution ===${NC}"
    
    # Test with obviously mutable tag (should not trigger API calls)
    test_start "Script execution with mutable tag"
    local output exit_code
    if output=$("$SCRIPT_DIR/check-immutable-tags.sh" "obviously-mutable-tag" 2>/dev/null); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]] && [[ "$output" == *"PUSH"* ]]; then
        test_pass "Script execution with mutable tag"
    else
        test_fail "Script execution with mutable tag" "Exit code: $exit_code, Output: $output"
    fi
    
    # Test JSON output format
    test_start "JSON output format"
    if output=$("$SCRIPT_DIR/check-immutable-tags.sh" --json "test-tag" 2>/dev/null); then
        if [[ "$output" == *"{"* ]] && [[ "$output" == *"}"* ]]; then
            test_pass "JSON output format"
        else
            test_fail "JSON output format" "Output not JSON formatted"
        fi
    else
        test_fail "JSON output format" "Script execution failed"
    fi
}

# Main test runner
run_tests() {
    echo -e "${BLUE}Starting tests for check-immutable-tags.sh${NC}\n"
    
    # Suppress normal script output during tests
    local old_quiet="${QUIET:-false}"
    QUIET="true"
    
    test_immutable_pattern_matching
    test_edge_cases
    test_argument_parsing
    test_json_functionality
    test_script_execution
    
    QUIET="$old_quiet"
    
    # Print summary
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Show usage for test script
test_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run unit tests for check-immutable-tags.sh

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    
EXAMPLES:
    $0
    $0 --verbose
EOF
}

# Parse test script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help)
            test_usage
            exit 0
            ;;
        -v|--verbose)
            DEBUG="true"
            run_tests
            ;;
        "")
            run_tests
            ;;
        *)
            echo "Unknown option: $1"
            test_usage
            exit 1
            ;;
    esac
fi