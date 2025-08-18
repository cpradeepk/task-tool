#!/bin/bash

# Playwright Test Runner for Task Management CRUD Operations
# This script sets up and runs comprehensive CRUD tests

set -e

# Configuration
TEST_DIR="tests/playwright"
REPO_DIR="/srv/task-tool"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

log "🎭 Starting Playwright CRUD Tests for Task Management Tool"
echo "=" | tr '\n' '=' | head -c 70; echo

# Step 1: Setup test environment
log "🔧 Setting up test environment..."

# Navigate to test directory
cd "$REPO_DIR/$TEST_DIR" || error "Test directory not found: $REPO_DIR/$TEST_DIR"

# Install dependencies if not already installed
if [ ! -d "node_modules" ]; then
    log "📦 Installing Playwright dependencies..."
    npm install || error "Failed to install dependencies"
fi

# Install browsers if not already installed
log "🌐 Installing/updating browsers..."
npx playwright install || error "Failed to install browsers"

# Step 2: Run the tests
log "🧪 Running CRUD tests..."

# Run tests with detailed output
info "Running Project, Module, Task, and Subtask CRUD tests..."
info "Target URL: https://task.amtariksha.com/task/"

# Run tests in headed mode for debugging (optional)
if [ "$1" = "--headed" ]; then
    log "Running tests in headed mode (visible browser)..."
    npx playwright test --headed --reporter=list
elif [ "$1" = "--debug" ]; then
    log "Running tests in debug mode..."
    npx playwright test --debug
elif [ "$1" = "--ui" ]; then
    log "Running tests with UI mode..."
    npx playwright test --ui
else
    log "Running tests in headless mode..."
    npx playwright test --reporter=list
fi

# Step 3: Generate and show report
log "📊 Generating test report..."
npx playwright show-report --host=0.0.0.0 --port=9323 &
REPORT_PID=$!

# Step 4: Display results
echo
log "🎉 Playwright tests completed!"
echo "=" | tr '\n' '=' | head -c 70; echo
echo
info "Test Results:"
info "  - Test report available at: http://localhost:9323"
info "  - Screenshots and videos saved in: test-results/"
info "  - Detailed logs available in: playwright-report/"
echo
info "Test Coverage:"
info "  ✅ Project CRUD operations"
info "  ✅ Module CRUD operations"  
info "  ✅ Task CRUD operations"
info "  ✅ Subtask CRUD operations"
info "  ✅ Performance testing"
info "  ✅ Error handling verification"
echo
info "Usage:"
info "  ./scripts/run-playwright-tests.sh           # Run headless tests"
info "  ./scripts/run-playwright-tests.sh --headed  # Run with visible browser"
info "  ./scripts/run-playwright-tests.sh --debug   # Run in debug mode"
info "  ./scripts/run-playwright-tests.sh --ui      # Run with UI mode"
echo

# Keep report server running for a while
info "Test report server will run for 5 minutes..."
info "Press Ctrl+C to stop the report server early"

sleep 300 # Keep report running for 5 minutes
kill $REPORT_PID 2>/dev/null || true

log "✅ Playwright testing session completed!"
