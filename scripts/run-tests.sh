#!/bin/bash

# SwargFood Task Management - Test Execution Script
# Comprehensive test runner with various options

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_SUITE="all"
BROWSER="chromium"
HEADED=false
DEBUG=false
REPORT=false
PARALLEL=true

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --suite SUITE     Test suite to run (all|auth|projects|tasks|time|api)"
    echo "  -b, --browser BROWSER Browser to use (chromium|firefox|webkit|all)"
    echo "  -h, --headed          Run tests in headed mode"
    echo "  -d, --debug           Run tests in debug mode"
    echo "  -r, --report          Show test report after execution"
    echo "  -p, --parallel        Run tests in parallel (default: true)"
    echo "  --no-parallel         Run tests sequentially"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s auth -b chromium -h"
    echo "  $0 --suite projects --browser firefox --debug"
    echo "  $0 -s all -b all --report"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        -b|--browser)
            BROWSER="$2"
            shift 2
            ;;
        -h|--headed)
            HEADED=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -r|--report)
            REPORT=true
            shift
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        --no-parallel)
            PARALLEL=false
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Validate test suite
case $TEST_SUITE in
    all|auth|projects|tasks|time|api)
        ;;
    *)
        echo -e "${RED}Error: Invalid test suite '$TEST_SUITE'${NC}"
        echo "Valid options: all, auth, projects, tasks, time, api"
        exit 1
        ;;
esac

# Validate browser
case $BROWSER in
    chromium|firefox|webkit|all)
        ;;
    *)
        echo -e "${RED}Error: Invalid browser '$BROWSER'${NC}"
        echo "Valid options: chromium, firefox, webkit, all"
        exit 1
        ;;
esac

echo -e "${BLUE}🚀 SwargFood Task Management Test Suite${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Test Suite: ${GREEN}$TEST_SUITE${NC}"
echo -e "  Browser: ${GREEN}$BROWSER${NC}"
echo -e "  Headed: ${GREEN}$HEADED${NC}"
echo -e "  Debug: ${GREEN}$DEBUG${NC}"
echo -e "  Parallel: ${GREEN}$PARALLEL${NC}"
echo ""

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Install browsers if needed
echo -e "${YELLOW}Checking Playwright browsers...${NC}"
npx playwright install --with-deps

# Build test command
TEST_CMD="npx playwright test"

# Add test suite filter
case $TEST_SUITE in
    auth)
        TEST_CMD="$TEST_CMD tests/e2e/01-authentication.spec.js"
        ;;
    projects)
        TEST_CMD="$TEST_CMD tests/e2e/02-project-management.spec.js"
        ;;
    tasks)
        TEST_CMD="$TEST_CMD tests/e2e/03-task-management.spec.js"
        ;;
    time)
        TEST_CMD="$TEST_CMD tests/e2e/04-time-tracking.spec.js"
        ;;
    api)
        TEST_CMD="$TEST_CMD tests/api/api-endpoints.spec.js"
        ;;
    all)
        # Run all tests
        ;;
esac

# Add browser filter
if [ "$BROWSER" != "all" ]; then
    TEST_CMD="$TEST_CMD --project=$BROWSER"
fi

# Add execution mode flags
if [ "$HEADED" = true ]; then
    TEST_CMD="$TEST_CMD --headed"
fi

if [ "$DEBUG" = true ]; then
    TEST_CMD="$TEST_CMD --debug"
fi

if [ "$PARALLEL" = false ]; then
    TEST_CMD="$TEST_CMD --workers=1"
fi

# Create results directory
mkdir -p test-results/screenshots

echo -e "${YELLOW}Executing tests...${NC}"
echo -e "${BLUE}Command: $TEST_CMD${NC}"
echo ""

# Run tests
START_TIME=$(date +%s)

if eval $TEST_CMD; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}✅ Tests completed successfully in ${DURATION}s${NC}"
    EXIT_CODE=0
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo ""
    echo -e "${RED}❌ Tests failed after ${DURATION}s${NC}"
    EXIT_CODE=1
fi

# Show report if requested
if [ "$REPORT" = true ]; then
    echo ""
    echo -e "${YELLOW}Opening test report...${NC}"
    npx playwright show-report
fi

# Summary
echo ""
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  Duration: ${DURATION}s"
echo -e "  Results: test-results/"
echo -e "  Screenshots: test-results/screenshots/"
echo -e "  HTML Report: playwright-report/"

exit $EXIT_CODE
