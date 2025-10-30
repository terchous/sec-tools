#!/bin/bash

# Local testing script that mimics GitHub Actions

set -e

echo "=== Local CI/CD Test ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name=$1
    shift
    local test_cmd="$@"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}[TEST $TESTS_RUN]${NC} $test_name"
    
    if eval "$test_cmd"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    echo ""
}

# Check dependencies
echo "Checking dependencies..."
command -v yq >/dev/null 2>&1 || { echo "yq not found. Install it first."; exit 1; }
command -v just >/dev/null 2>&1 || { echo "just not found. Install it first."; exit 1; }

# Run tests
run_test "Validate YAML configuration" "just validate-config"
run_test "Dry run installation" "./install.sh --dry-run"
run_test "Check for duplicate tools" "! yq eval '.go_tools[].name' config/tools.yaml | sort | uniq -d | grep ."
run_test "Verify all shell scripts" "find . -name '*.sh' -type f -exec bash -n {} \;"
run_test "Test logger module" "bash -c 'source lib/logger.sh && log_info \"test\"'"
run_test "Test core module" "bash -c 'source lib/core.sh && command_exists bash'"

# Summary
echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "Failed: $TESTS_FAILED"
    echo -e "${GREEN}All tests passed!${NC}"
fi
