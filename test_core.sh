#!/bin/bash
source lib/core.sh

log_info "Testing logger..."
log_success "Success message"
log_warn "Warning message"
log_error "Error message" || true
log_debug "Debug message (set DEBUG=1 to see)"

log_info "Testing utility functions..."
if command_exists "bash"; then
    log_success "command_exists works"
fi

safe_mkdir ~/test_dir
if dir_exists ~/test_dir; then
    log_success "safe_mkdir works"
    rmdir ~/test_dir
fi

log_info "Core utilities test complete!"