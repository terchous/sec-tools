#!/bin/bash

echo "Testing modules..."

# Test logger
source lib/logger.sh
log_info "Testing logger module"
log_success "Logger works!"

# Test core utilities
source lib/core.sh
log_info "Testing core utilities"
if command_exists bash; then
    log_success "command_exists works"
fi

# Test path expansion
expanded=$(expand_path "~/test")
log_info "Path expansion: ~/test -> $expanded"

log_success "Module tests complete!"