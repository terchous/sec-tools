#!/bin/bash

# Source guard
if [ -n "${_PACKAGE_MANAGER_SH_LOADED:-}" ]; then
    return 0
fi
_PACKAGE_MANAGER_SH_LOADED=1

SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/core.sh"

# Update package cache
pkg_update() {
    log_info "Updating package cache..."
    retry 3 sudo apt-get update -yq
    log_success "Package cache updated"
}

# Upgrade packages
pkg_upgrade() {
    log_info "Upgrading packages..."
    sudo apt-get upgrade -yq
    log_success "Packages upgraded"
}

# Install single package
pkg_install() {
    local package=$1
    
    if dpkg -l | grep -q "^ii  $package "; then
        log_debug "$package already installed"
        return 0
    fi
    
    log_info "Installing $package..."
    if sudo apt-get install "$package" -yq; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Install multiple packages from array
pkg_install_batch() {
    local -n packages=$1
    local failed=()
    
    log_info "Installing ${#packages[@]} packages..."
    
    for package in "${packages[@]}"; do
        if ! pkg_install "$package"; then
            failed+=("$package")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to install: ${failed[*]}"
        return 1
    fi
    
    log_success "All packages installed successfully"
    return 0
}

# Install packages from YAML
pkg_install_from_yaml() {
    local yaml_file=$1
    local category=${2:-"apt_packages"}
    
    log_info "Reading packages from $yaml_file ($category)..."
    
    # Read packages from YAML
    local packages=($(yq eval ".${category}[]" "$yaml_file"))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_warn "No packages found in $category"
        return 0
    fi
    
    pkg_install_batch packages
}