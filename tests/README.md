# Comprehensive Testing Framework for Immutable Tag Handling

This directory contains a comprehensive testing framework for validating immutable tag detection, workflow behavior, and edge case handling as specified in issue #25.

## Directory Structure

```
tests/
├── README.md                          # This file
├── unit/                              # Unit tests
│   ├── tag-pattern.test.sh           # Tag pattern matching tests
│   └── api-client.test.sh            # API client and response handling tests
├── integration/                       # Integration tests
│   └── docker-hub-api.test.sh        # Docker Hub API integration tests
└── fixtures/                         # Test data and mock responses
    ├── test-data/
    │   ├── tag-patterns.json          # Tag pattern test cases
    │   └── workflow-scenarios.json    # Workflow scenario definitions
    └── api-responses/
        ├── docker-hub-auth-success.json
        └── docker-hub-auth-failure.json
```

## Test Suites

### Unit Tests

#### Tag Pattern Tests (`unit/tag-pattern.test.sh`)
- **Purpose**: Comprehensive validation of immutable tag pattern matching
- **Coverage**: 
  - Valid immutable patterns (alpine-X.Y.Z format)
  - Invalid mutable patterns (commit prefixes, suffixes, etc.)
  - Edge cases (empty strings, malformed versions)
  - Performance testing (1000+ pattern matches)
  - Regex behavior validation

#### API Client Tests (`unit/api-client.test.sh`)
- **Purpose**: Test API client functionality and response handling
- **Coverage**:
  - JSON parsing with jq and fallback methods
  - HTTP response code handling (200, 404, 401/403, 429, 5xx)
  - curl command construction
  - Error handling scenarios
  - Logging integration

### Integration Tests

#### Docker Hub API Tests (`integration/docker-hub-api.test.sh`)
- **Purpose**: End-to-end testing with Docker Hub API
- **Coverage**:
  - Authentication token retrieval
  - Manifest existence checking
  - Rate limiting behavior
  - Network error handling
  - Multiple tag scenarios
  - JSON output validation
  - Debug output verification

**Note**: Integration tests can skip live API calls by setting `SKIP_LIVE_TESTS=true`

## Test Runner

### Main Test Runner (`../run-tests.sh`)

Comprehensive test execution with multiple options:

```bash
# Run all tests
./run-tests.sh

# Run specific test suites
./run-tests.sh unit
./run-tests.sh integration
./run-tests.sh pattern      # Just tag pattern tests
./run-tests.sh api         # Just API client tests

# Options
./run-tests.sh --verbose    # Detailed output
./run-tests.sh --coverage   # Generate coverage report
./run-tests.sh --skip-live  # Skip live API tests
./run-tests.sh --no-unit    # Skip unit tests
```

### Exit Codes
- `0`: All tests passed
- `1`: Some tests failed
- `2`: Test execution error
- `3`: Prerequisites not met

## Test Data and Fixtures

### Tag Pattern Test Data (`fixtures/test-data/tag-patterns.json`)
Comprehensive collection of test cases:
- **Immutable tags**: Valid alpine-X.Y.Z patterns
- **Mutable tags**: Invalid patterns that should not match

### Workflow Scenarios (`fixtures/test-data/workflow-scenarios.json`)
Predefined scenarios for integration testing:
- All tags new (normal push)
- Mixed immutable/mutable tags (partial skip)
- API failures (graceful degradation)
- Feature branch safety validation

### Mock API Responses (`fixtures/api-responses/`)
- Docker Hub authentication success/failure responses
- Used for offline testing without API calls

## Environment Variables

### Test Configuration
- `RUN_UNIT_TESTS`: Enable/disable unit tests (default: true)
- `RUN_INTEGRATION_TESTS`: Enable/disable integration tests (default: true)
- `RUN_LEGACY_TESTS`: Enable/disable legacy tests (default: true)
- `SKIP_LIVE_TESTS`: Skip live API calls (default: false)
- `VERBOSE`: Enable verbose output (default: false)
- `COVERAGE_REPORT`: Generate coverage report (default: false)

### Integration Test Configuration
- `INTEGRATION_REGISTRY`: Registry for integration tests (default: liskl/base)

## CI/CD Integration

### GitHub Actions Workflow (`.github/workflows/test-validation.yaml`)

The testing framework is integrated into CI/CD with multiple validation stages:

1. **Test Execution**: Run all test suites in parallel
2. **Coverage Reporting**: Generate comprehensive coverage analysis
3. **Syntax Validation**: Validate shell script syntax
4. **Integration Smoke Tests**: Basic functionality validation
5. **Summary Reporting**: Aggregate results with GitHub step summaries

### Workflow Triggers
- Push to `master` branch
- Pull requests to `master`
- Manual workflow dispatch
- Feature branch pushes (for testing branches)

## Test Coverage

### Current Coverage Areas

✅ **Tag Pattern Matching**
- Immutable pattern validation
- Mutable pattern rejection
- Edge case handling
- Performance validation

✅ **API Client Functionality**
- JSON parsing (jq + fallback)
- HTTP response handling
- Error scenarios
- Logging integration

✅ **Docker Hub Integration**
- Authentication flow
- Manifest checking
- Rate limiting
- Network errors

✅ **Workflow Integration**
- Feature branch validation
- Mixed tag scenarios
- JSON output format
- Debug output

### Coverage Gaps
- Workflow end-to-end testing (requires Docker Hub writes)
- Multi-architecture tag scenarios
- Concurrent API request handling
- Performance under load

## Running Tests Locally

### Prerequisites
```bash
# Required
bash (4.0+)
curl

# Recommended
jq (for JSON parsing)
```

### Quick Start
```bash
# Make scripts executable
chmod +x scripts/*.sh tests/unit/*.sh tests/integration/*.sh run-tests.sh

# Run all tests (skip live API calls)
./run-tests.sh --skip-live

# Run specific test suite
./run-tests.sh unit

# Generate coverage report
./run-tests.sh --coverage all
```

### Debugging Tests
```bash
# Run with verbose output
./run-tests.sh --verbose unit

# Run individual test files
./tests/unit/tag-pattern.test.sh
./tests/integration/docker-hub-api.test.sh --skip-live

# Test main script directly
./scripts/check-immutable-tags.sh --debug test-tag
```

## Test Development Guidelines

### Adding New Tests

1. **Unit Tests**: Add to appropriate file in `tests/unit/`
2. **Integration Tests**: Add to `tests/integration/`
3. **Test Data**: Update fixtures in `tests/fixtures/`
4. **Documentation**: Update this README

### Test Function Naming
- `test_<functionality>()`: Main test functions
- `test_<component>_<scenario>()`: Specific scenario tests
- Use descriptive names that explain what is being tested

### Test Output Format
- Use provided test helper functions (`test_start`, `test_pass`, `test_fail`)
- Include descriptive failure messages
- Maintain consistent color coding

### Error Handling
- Tests should be resilient to environment differences
- Gracefully handle missing dependencies
- Provide clear error messages for failures

## Performance Considerations

### Test Execution Time
- Unit tests: < 5 seconds
- Integration tests (offline): < 10 seconds  
- Integration tests (with live API): < 30 seconds
- Full test suite: < 60 seconds

### Resource Usage
- Minimal memory footprint
- No persistent state between tests
- Clean up temporary files

## Security Considerations

### API Testing
- No credentials stored in test files
- Live tests use public Docker Hub API only
- No sensitive data in test fixtures
- Rate limiting respected

### Test Isolation
- Tests don't modify system state
- No network access required for core tests
- Safe to run in CI environments

## Troubleshooting

### Common Issues

**Tests hang or timeout**:
- Check shell script syntax: `bash -n script.sh`
- Verify file permissions: `ls -la tests/`
- Run with debug: `DEBUG=true ./run-tests.sh`

**API tests fail**:
- Check network connectivity
- Verify curl is available
- Use `--skip-live` for offline testing

**JSON parsing errors**:
- Install jq: `sudo apt-get install jq`
- Tests will fallback to sed parsing

**Coverage report issues**:
- Ensure all test files are executable
- Check that test functions are properly named
- Verify test output format consistency

### Getting Help

1. Check test output for specific error messages
2. Run individual test files for isolation
3. Use `--verbose` flag for detailed output
4. Review CI logs for environment-specific issues

## Contributing

When adding new test functionality:

1. Follow existing test structure and naming conventions
2. Add appropriate test data to fixtures
3. Update this documentation
4. Ensure tests pass in CI environment
5. Consider both positive and negative test cases

## Related Documentation

- Main project: `../CLAUDE.md`
- Immutable tag script: `../scripts/check-immutable-tags.sh`
- CI/CD workflows: `../.github/workflows/`
- Issue tracking: GitHub issue #25