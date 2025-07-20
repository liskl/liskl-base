#!/bin/bash

# run-tests.sh
# Comprehensive test runner for immutable tag handling
# Part of issue #25 implementation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
TESTS_DIR="$PROJECT_ROOT/tests"

# Test configuration
RUN_UNIT_TESTS="${RUN_UNIT_TESTS:-true}"
RUN_INTEGRATION_TESTS="${RUN_INTEGRATION_TESTS:-true}"
RUN_LEGACY_TESTS="${RUN_LEGACY_TESTS:-true}"
SKIP_LIVE_TESTS="${SKIP_LIVE_TESTS:-false}"
VERBOSE="${VERBOSE:-false}"
COVERAGE_REPORT="${COVERAGE_REPORT:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results tracking
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
FAILED_SUITES=()

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_section() {
    echo -e "\n${CYAN}=== $* ===${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_SUITE]

Run comprehensive tests for immutable tag handling functionality.

TEST_SUITES:
    all                     Run all test suites (default)
    unit                    Run only unit tests
    integration             Run only integration tests
    legacy                  Run only legacy test script
    pattern                 Run only tag pattern tests
    api                     Run only API client tests

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -c, --coverage          Generate coverage report
    -s, --skip-live         Skip live API tests
    -q, --quiet             Minimal output (errors only)
    --no-unit              Skip unit tests
    --no-integration       Skip integration tests
    --no-legacy            Skip legacy tests

ENVIRONMENT VARIABLES:
    RUN_UNIT_TESTS          Run unit tests (true/false)
    RUN_INTEGRATION_TESTS   Run integration tests (true/false)
    RUN_LEGACY_TESTS        Run legacy tests (true/false)
    SKIP_LIVE_TESTS         Skip live API tests (true/false)
    VERBOSE                 Enable verbose output (true/false)
    COVERAGE_REPORT         Generate coverage report (true/false)

EXAMPLES:
    $0                      # Run all tests
    $0 unit                 # Run only unit tests
    $0 --skip-live          # Run tests but skip live API calls
    $0 -v integration       # Run integration tests with verbose output
    $0 --coverage all       # Run all tests with coverage reporting

EXIT CODES:
    0   All tests passed
    1   Some tests failed
    2   Test execution error
    3   Prerequisites not met

EOF
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        log_warning "curl not found - some integration tests may fail"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not found - JSON parsing will use fallback methods"
    fi
    
    # Check for test files
    local required_files=(
        "$PROJECT_ROOT/scripts/check-immutable-tags.sh"
        "$TESTS_DIR/unit/tag-pattern.test.sh"
        "$TESTS_DIR/unit/api-client.test.sh"
        "$TESTS_DIR/integration/docker-hub-api.test.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_deps+=("$file")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing prerequisites:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

# Run a test suite and capture results
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local suite_args="${3:-}"
    
    log_section "Running $suite_name Tests"
    
    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        FAILED_SUITES+=("$suite_name")
        return 1
    fi
    
    # Make sure test script is executable
    chmod +x "$test_script"
    
    local start_time=$(date +%s)
    local test_output
    local exit_code
    
    # Run test and capture output
    if [[ "$VERBOSE" == "true" ]]; then
        if test_output=$("$test_script" $suite_args 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        echo "$test_output"
    else
        if test_output=$("$test_script" $suite_args 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse test results from output
    local tests_run=0
    local tests_passed=0
    local tests_failed=0
    
    if echo "$test_output" | grep -q "Tests run:"; then
        tests_run=$(echo "$test_output" | grep "Tests run:" | sed 's/.*Tests run: \([0-9]*\).*/\1/')
        tests_passed=$(echo "$test_output" | grep "Tests passed:" | sed 's/.*Tests passed: \([0-9]*\).*/\1/')
        tests_failed=$(echo "$test_output" | grep "Tests failed:" | sed 's/.*Tests failed: \([0-9]*\).*/\1/')
    fi
    
    # Update global counters
    TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
    TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))
    
    # Report results
    if [[ $exit_code -eq 0 ]]; then
        log_success "$suite_name tests completed successfully (${duration}s)"
        if [[ $tests_run -gt 0 ]]; then
            echo "  Tests run: $tests_run, Passed: $tests_passed, Failed: $tests_failed"
        fi
    else
        log_error "$suite_name tests failed (exit code: $exit_code, duration: ${duration}s)"
        if [[ $tests_run -gt 0 ]]; then
            echo "  Tests run: $tests_run, Passed: $tests_passed, Failed: $tests_failed"
        fi
        if [[ "$VERBOSE" != "true" ]]; then
            echo "Output:"
            echo "$test_output" | sed 's/^/  /'
        fi
        FAILED_SUITES+=("$suite_name")
    fi
    
    return $exit_code
}

# Run unit tests
run_unit_tests() {
    if [[ "$RUN_UNIT_TESTS" != "true" ]]; then
        log_info "Skipping unit tests (disabled)"
        return 0
    fi
    
    local unit_failed=0
    
    # Run tag pattern tests
    if ! run_test_suite "Tag Pattern" "$TESTS_DIR/unit/tag-pattern.test.sh"; then
        unit_failed=1
    fi
    
    # Run API client tests
    if ! run_test_suite "API Client" "$TESTS_DIR/unit/api-client.test.sh"; then
        unit_failed=1
    fi
    
    return $unit_failed
}

# Run integration tests
run_integration_tests() {
    if [[ "$RUN_INTEGRATION_TESTS" != "true" ]]; then
        log_info "Skipping integration tests (disabled)"
        return 0
    fi
    
    local integration_args=""
    if [[ "$SKIP_LIVE_TESTS" == "true" ]]; then
        integration_args="--skip-live"
    fi
    
    run_test_suite "Docker Hub API Integration" "$TESTS_DIR/integration/docker-hub-api.test.sh" "$integration_args"
}

# Run legacy tests (existing test script)
run_legacy_tests() {
    if [[ "$RUN_LEGACY_TESTS" != "true" ]]; then
        log_info "Skipping legacy tests (disabled)"
        return 0
    fi
    
    local legacy_script="$PROJECT_ROOT/scripts/test-check-immutable-tags.sh"
    if [[ -f "$legacy_script" ]]; then
        run_test_suite "Legacy" "$legacy_script"
    else
        log_warning "Legacy test script not found: $legacy_script"
    fi
}

# Generate coverage report
generate_coverage_report() {
    if [[ "$COVERAGE_REPORT" != "true" ]]; then
        return 0
    fi
    
    log_section "Coverage Report"
    
    # Basic coverage analysis by examining test files
    local script_file="$PROJECT_ROOT/scripts/check-immutable-tags.sh"
    local total_functions=0
    local tested_functions=0
    
    if [[ -f "$script_file" ]]; then
        # Count functions in main script
        total_functions=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$script_file" || echo "0")
        
        # Count functions tested (basic heuristic)
        local test_files=("$TESTS_DIR"/unit/*.test.sh "$TESTS_DIR"/integration/*.test.sh)
        for test_file in "${test_files[@]}"; do
            if [[ -f "$test_file" ]]; then
                # Look for function calls in test files
                while IFS= read -r func; do
                    local func_name
                    func_name=$(echo "$func" | sed 's/() {.*//')
                    if grep -q "$func_name" "$test_file" 2>/dev/null; then
                        ((tested_functions++))
                    fi
                done < <(grep "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$script_file")
            fi
        done
    fi
    
    echo "Script Analysis:"
    echo "  Total functions: $total_functions"
    echo "  Functions with tests: $tested_functions"
    if [[ $total_functions -gt 0 ]]; then
        local coverage_percent=$((tested_functions * 100 / total_functions))
        echo "  Estimated coverage: ${coverage_percent}%"
    fi
    
    echo ""
    echo "Test Files:"
    find "$TESTS_DIR" -name "*.test.sh" -exec wc -l {} + | sort -n
}

# Print final summary
print_summary() {
    log_section "Test Summary"
    
    echo "Total tests run: $TOTAL_TESTS"
    echo -e "Tests passed: ${GREEN}$TOTAL_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TOTAL_FAILED${NC}"
    
    if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed test suites:${NC}"
        for suite in "${FAILED_SUITES[@]}"; do
            echo "  - $suite"
        done
    fi
    
    if [[ $TOTAL_FAILED -eq 0 && ${#FAILED_SUITES[@]} -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed!${NC}"
        return 1
    fi
}

# Main test execution
main() {
    local test_suite="${1:-all}"
    
    echo -e "${CYAN}Immutable Tag Handling - Comprehensive Test Suite${NC}"
    echo "================================================"
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 3
    fi
    
    local start_time=$(date +%s)
    local overall_result=0
    
    # Run requested test suites
    case "$test_suite" in
        "all")
            run_unit_tests || overall_result=1
            run_integration_tests || overall_result=1
            run_legacy_tests || overall_result=1
            ;;
        "unit")
            run_unit_tests || overall_result=1
            ;;
        "integration")
            run_integration_tests || overall_result=1
            ;;
        "legacy")
            run_legacy_tests || overall_result=1
            ;;
        "pattern")
            run_test_suite "Tag Pattern" "$TESTS_DIR/unit/tag-pattern.test.sh" || overall_result=1
            ;;
        "api")
            run_test_suite "API Client" "$TESTS_DIR/unit/api-client.test.sh" || overall_result=1
            ;;
        *)
            log_error "Unknown test suite: $test_suite"
            show_usage
            exit 2
            ;;
    esac
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    generate_coverage_report
    
    echo ""
    echo "Total execution time: ${total_duration}s"
    
    if ! print_summary; then
        exit 1
    fi
    
    exit $overall_result
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -c|--coverage)
            COVERAGE_REPORT="true"
            shift
            ;;
        -s|--skip-live)
            SKIP_LIVE_TESTS="true"
            shift
            ;;
        -q|--quiet)
            VERBOSE="false"
            shift
            ;;
        --no-unit)
            RUN_UNIT_TESTS="false"
            shift
            ;;
        --no-integration)
            RUN_INTEGRATION_TESTS="false"
            shift
            ;;
        --no-legacy)
            RUN_LEGACY_TESTS="false"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 2
            ;;
        *)
            # This is the test suite argument
            break
            ;;
    esac
done

# Run main function with remaining arguments
main "$@"