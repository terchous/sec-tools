#!/bin/bash

# Source guard
if [ -n "${_GO_INSTALLER_SH_LOADED:-}" ]; then
    return 0
fi
_GO_INSTALLER_SH_LOADED=1

SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/core.sh"

# Go binary path
GO_BIN="${GO_BIN:-$HOME/go/bin}"

# Install Go itself
install_golang() {
    local version="${1:-1.21.0}"
    local install_path="/usr/local/go"
    
    if command_exists go && dir_exists "$install_path"; then
        local current_version=$(go version | grep -oP '\d+\.\d+\.\d+')
        log_info "Go $current_version already installed"
        return 0
    fi
    
    log_info "Installing Go $version..."
    
    local tarball="go${version}.linux-amd64.tar.gz"
    local url="https://go.dev/dl/${tarball}"
    
    safe_download "$url" "/tmp/$tarball"
    
    tar -xzf "/tmp/$tarball" -C /tmp
    sudo mv /tmp/go "$install_path"
    rm -f "/tmp/$tarball"
    
    # Add to PATH if not already there
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
        log_info "Added Go to PATH in ~/.bashrc"
    fi
    
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    
    log_success "Installed Go $(go version)"
}

# Install single Go tool
go_install_tool() {
    local tool_name=$1
    local install_cmd=$2
    local binary_path="${3:-$GO_BIN/$tool_name}"
    
    # Always expand the path to handle ~ properly
    binary_path=$(expand_path "$binary_path")
    
    # Check if already installed at the specific binary path
    if file_exists "$binary_path"; then
        log_debug "$tool_name already installed at $binary_path"
        return 0
    fi
    
    log_info "Installing $tool_name to $binary_path..."
    log_debug "Command: $install_cmd"
    
    if eval "$install_cmd"; then
        # Verify the binary was actually created
        if file_exists "$binary_path"; then
            log_success "Installed $tool_name at $binary_path"
            return 0
        else
            log_warn "Installation succeeded but binary not found at expected path: $binary_path"
            return 0
        fi
    else
        log_error "Failed to install $tool_name"
        return 1
    fi
}

# Install Go tools from YAML with dependency support
go_install_from_yaml() {
    local yaml_file=$1
    local category=${2:-"go_tools"}
    
    log_info "Installing Go tools from $yaml_file..."
    
    # Ensure Go is installed
    if ! command_exists go; then
        log_error "Go is not installed. Run install_golang first."
        return 1
    fi
    
    # Get tool count
    local tool_count=$(yq eval ".${category} | length" "$yaml_file")
    
    if [ "$tool_count" = "0" ] || [ "$tool_count" = "null" ]; then
        log_warn "No Go tools found in $category"
        return 0
    fi
    
    log_info "Found $tool_count Go tools to install"
    
    # Iterate through tools
    local failed=()
    for i in $(seq 0 $((tool_count - 1))); do
        local name=$(yq eval ".${category}[$i].name" "$yaml_file")
        local cmd=$(yq eval ".${category}[$i].install" "$yaml_file")
        local binary=$(yq eval ".${category}[$i].binary" "$yaml_file")
        local dependencies_count=$(yq eval ".${category}[$i].dependencies | length" "$yaml_file")
        
        # Install dependencies if any
        if [ "$dependencies_count" != "null" ] && [ "$dependencies_count" -gt 0 ]; then
            local dependencies=()
            for j in $(seq 0 $((dependencies_count - 1))); do
                local dep=$(yq eval ".${category}[$i].dependencies[$j]" "$yaml_file")
                dependencies+=("$dep")
            done
            log_info "Installing dependencies for $name: ${dependencies[*]}"
            if ! pkg_install "${dependencies[@]}"; then
                log_warn "Failed to install some dependencies for $name"
            fi
        fi
        
        # Use default binary path if not specified
        if [ "$binary" = "null" ] || [ -z "$binary" ]; then
            binary="$GO_BIN/$name"
        fi
        
        if ! go_install_tool "$name" "$cmd" "$binary"; then
            failed+=("$name")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to install: ${failed[*]}"
        return 1
    fi
    
    log_success "All Go tools installed successfully"
    return 0
}

# Clean Go cache
go_cleanup() {
    log_info "Cleaning Go cache..."
    go clean -cache
    go clean -modcache
    log_success "Go cache cleaned"
}