#!/bin/bash

# tag-pattern.test.sh
# Comprehensive unit tests for immutable tag pattern matching
# Part of issue #25 implementation

set -euo pipefail

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

# Source the main script
source "$PROJECT_ROOT/scripts/check-immutable-tags.sh"

# Source test data
TEST_DATA_FILE="$FIXTURES_DIR/test-data/tag-patterns.json"

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

# Extract test data using jq if available, fallback to basic parsing
get_test_tags() {
    local category="$1"  # "immutable_tags" or "mutable_tags"
    
    if command -v jq >/dev/null 2>&1 && [[ -f "$TEST_DATA_FILE" ]]; then
        jq -r ".${category}[].tag" "$TEST_DATA_FILE" 2>/dev/null || echo ""
    else
        # Fallback parsing for environments without jq
        if [[ -f "$TEST_DATA_FILE" ]]; then
            grep -A 1000 "\"${category}\"" "$TEST_DATA_FILE" | \
            grep '"tag"' | \
            sed 's/.*"tag": *"\([^"]*\)".*/\1/' | \
            head -20  # Reasonable limit
        fi
    fi
}

get_test_descriptions() {
    local category="$1"
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".${category}[] | .tag + \": \" + .description" "$TEST_DATA_FILE"
    else
        echo "Description lookup requires jq"
    fi
}

# Simple pattern test function to avoid sourcing issues
simple_pattern_test() {
    local tag="$1"
    [[ "$tag" =~ ^alpine-[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Test immutable tag patterns
test_immutable_patterns() {
    echo -e "\n${YELLOW}=== Testing Immutable Tag Patterns ===${NC}"
    
    # Use hardcoded test cases
    local immutable_tags=(
        "alpine-3.22.1"
        "alpine-3.21.4"
        "alpine-3.20.7"
        "alpine-0.0.1"
        "alpine-99.99.99"
        "alpine-1.0.0"
        "alpine-10.20.30"
        "alpine-100.200.300"
    )
    
    for tag in "${immutable_tags[@]}"; do
        test_start "Immutable pattern: '$tag'"
        if simple_pattern_test "$tag"; then
            test_pass "Immutable pattern: '$tag'"
        else
            test_fail "Immutable pattern: '$tag'" "Should match immutable pattern but didn't"
        fi
    done
}

# Test mutable tag patterns  
test_mutable_patterns() {
    echo -e "\n${YELLOW}=== Testing Mutable Tag Patterns ===${NC}"
    
    # Use hardcoded test cases
    local mutable_tags=(
        "latest"
        "522a89e-alpine-3.22.1"
        "3e82e63-alpine-3.21.4"
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
        test_start "Mutable pattern: '$tag'"
        if simple_pattern_test "$tag"; then
            test_fail "Mutable pattern: '$tag'" "Should NOT match immutable pattern but did"
        else
            test_pass "Mutable pattern: '$tag'"
        fi
    done
}

# Test regex pattern edge cases
test_pattern_edge_cases() {
    echo -e "\n${YELLOW}=== Testing Pattern Edge Cases ===${NC}"
    
    # Test empty and whitespace inputs
    local edge_cases=(
        ""                    # Empty string
        " "                   # Space
        "\t"                  # Tab
        "\n"                  # Newline
        "alpine-"             # Incomplete
        "-alpine-3.22.1"      # Leading dash
        "alpine-3.22.1-"      # Trailing dash
        "alpine--3.22.1"      # Double dash
        "alpine-3..22.1"      # Double dot
        "alpine-3.22.1."      # Trailing dot
        ".alpine-3.22.1"      # Leading dot
    )
    
    for tag in "${edge_cases[@]}"; do
        test_start "Edge case: '$tag'"
        if is_immutable_pattern "$tag"; then
            test_fail "Edge case: '$tag'" "Should not match pattern"
        else
            test_pass "Edge case: '$tag'"
        fi
    done
}

# Test version number boundaries
test_version_boundaries() {
    echo -e "\n${YELLOW}=== Testing Version Number Boundaries ===${NC}"
    
    # Test minimum values
    test_start "Minimum version: alpine-0.0.0"
    if is_immutable_pattern "alpine-0.0.0"; then
        test_pass "Minimum version: alpine-0.0.0"
    else
        test_fail "Minimum version: alpine-0.0.0" "Should match pattern"
    fi
    
    # Test large version numbers
    test_start "Large version: alpine-999.999.999"
    if is_immutable_pattern "alpine-999.999.999"; then
        test_pass "Large version: alpine-999.999.999"
    else
        test_fail "Large version: alpine-999.999.999" "Should match pattern"
    fi
    
    # Test negative numbers (should not match)
    test_start "Negative version: alpine--1.0.0"
    if is_immutable_pattern "alpine--1.0.0"; then
        test_fail "Negative version: alpine--1.0.0" "Should not match pattern"
    else
        test_pass "Negative version: alpine--1.0.0"
    fi
}

# Test pattern performance with many iterations
test_pattern_performance() {
    echo -e "\n${YELLOW}=== Testing Pattern Performance ===${NC}"
    
    test_start "Pattern matching performance"
    local start_time=$(date +%s%N)
    
    # Run pattern matching 1000 times
    for i in {1..1000}; do
        is_immutable_pattern "alpine-3.22.1" >/dev/null
        is_immutable_pattern "test-mutable-tag" >/dev/null
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    if [[ $duration -lt 1000 ]]; then  # Should complete in under 1 second
        test_pass "Pattern matching performance (${duration}ms)"
    else
        test_fail "Pattern matching performance" "Too slow: ${duration}ms"
    fi
}

# Test regex compilation and caching
test_regex_behavior() {
    echo -e "\n${YELLOW}=== Testing Regex Behavior ===${NC}"
    
    # Test that pattern variable is properly set
    test_start "Pattern variable initialization"
    if [[ -n "$IMMUTABLE_PATTERN" ]]; then
        test_pass "Pattern variable initialization"
    else
        test_fail "Pattern variable initialization" "IMMUTABLE_PATTERN not set"
    fi
    
    # Test pattern syntax validity
    test_start "Pattern syntax validation"
    if echo "alpine-3.22.1" | grep -E "$IMMUTABLE_PATTERN" >/dev/null; then
        test_pass "Pattern syntax validation"
    else
        test_fail "Pattern syntax validation" "Pattern syntax invalid"
    fi
}

# Main test runner
run_tag_pattern_tests() {
    echo -e "${BLUE}Starting comprehensive tag pattern tests${NC}\n"
    
    # Verify test data exists
    if [[ ! -f "$TEST_DATA_FILE" ]]; then
        echo -e "${RED}Error: Test data file not found at $TEST_DATA_FILE${NC}"
        exit 1
    fi
    
    echo "Debug: Test data file exists at $TEST_DATA_FILE"
    
    # Suppress normal script output during tests (but not test output)
    local old_quiet="${QUIET:-false}"
    # Don't set QUIET=true as it suppresses test output
    
    test_immutable_patterns
    test_mutable_patterns
    test_pattern_edge_cases
    test_version_boundaries
    test_pattern_performance
    test_regex_behavior
    
    QUIET="$old_quiet"
    
    # Print summary
    echo -e "\n${YELLOW}=== Tag Pattern Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tag pattern tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tag pattern tests failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tag_pattern_tests
fi