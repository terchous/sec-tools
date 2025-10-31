#!/bin/bash

# Source guard
if [ -n "${_PYTHON_INSTALLER_SH_LOADED:-}" ]; then
    return 0
fi
_PYTHON_INSTALLER_SH_LOADED=1

SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/core.sh"

# UV installation paths
UV_HOME="${UV_HOME:-$HOME/.cargo}"
UV_BIN="$UV_HOME/bin"
UV_BINARY="$UV_BIN/uv"

# Detect if running in CI
is_ci() {
    [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]
}

# Add UV to PATH for current session
add_uv_to_path() {
    if [[ ":$PATH:" != *":$UV_BIN:"* ]]; then
        export PATH="$UV_BIN:$PATH"
        log_debug "Added $UV_BIN to PATH for current session"
    fi
}

# Add UV to shell RC files
add_uv_to_shell_rc() {
    # Skip in CI environments
    if is_ci; then
        log_debug "Running in CI, skipping shell RC update"
        return 0
    fi
    
    local shell_rc=""
    
    # Detect shell and RC file
    if [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if already in RC file
    if [ -f "$shell_rc" ] && grep -q "\.cargo/bin" "$shell_rc"; then
        log_debug "UV already in $shell_rc"
        return 0
    fi
    
    log_info "Adding UV to $shell_rc"
    
    cat >> "$shell_rc" << 'UV_PATH_EOF'

# UV (Rust-based Python package manager)
export PATH="$HOME/.cargo/bin:$PATH"
UV_PATH_EOF
    
    log_success "Added UV to $shell_rc"
}

# Install UV directly (binary download - works best in CI)
install_uv_direct() {
    log_info "Installing UV via direct binary download..."
    
    # Detect architecture and OS
    local os="unknown-linux-gnu"
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    # Get latest version from GitHub API
    local uv_version=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$uv_version" ]; then
        log_warn "Could not detect latest version, using fallback"
        uv_version="0.4.30"
    fi
    
    log_info "Installing UV version: $uv_version"
    
    local uv_url="https://github.com/astral-sh/uv/releases/download/${uv_version}/uv-${arch}-${os}.tar.gz"
    local temp_dir=$(mktemp -d)
    
    # Download
    log_info "Downloading from: $uv_url"
    if ! wget -q --show-progress "$uv_url" -O "$temp_dir/uv.tar.gz"; then
        log_error "Failed to download UV"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract
    log_info "Extracting UV..."
    tar -xzf "$temp_dir/uv.tar.gz" -C "$temp_dir"
    
    # Create directory
    safe_mkdir "$UV_BIN"
    
    # Find and move binary
    local uv_binary=$(find "$temp_dir" -name "uv" -type f | head -n1)
    if [ -z "$uv_binary" ]; then
        log_error "UV binary not found in archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    mv "$uv_binary" "$UV_BINARY"
    chmod +x "$UV_BINARY"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "UV binary installed to: $UV_BINARY"
    
    # Verify
    if [ -f "$UV_BINARY" ]; then
        log_success "UV installation verified"
        return 0
    else
        log_error "UV binary not found after installation"
        return 1
    fi
}

# Install UV using official installer (may fail in CI)
install_uv_official() {
    log_info "Installing UV via official installer..."
    
    # Create .cargo/bin directory if it doesn't exist
    safe_mkdir "$UV_BIN"
    
    # Install uv using the official installer
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log_success "UV installer completed"
        
        # Check if binary exists
        if [ -f "$UV_BINARY" ]; then
            log_success "UV binary found at: $UV_BINARY"
            return 0
        else
            log_error "UV binary not found after installation"
            log_error "Expected location: $UV_BINARY"
            return 1
        fi
    else
        log_error "UV installer failed"
        return 1
    fi
}

# Install uv (the modern Python package installer)
install_uv() {
    # First, add to PATH if uv already exists but isn't in PATH
    if [ -f "$UV_BINARY" ]; then
        add_uv_to_path
        if command_exists uv || "$UV_BINARY" --version >/dev/null 2>&1; then
            local version=$("$UV_BINARY" --version 2>/dev/null | head -n1)
            log_info "uv already installed: $version"
            return 0
        fi
    fi
    
    # Check if uv is in PATH (might be installed elsewhere)
    if command_exists uv; then
        local version=$(uv --version 2>/dev/null | head -n1)
        log_info "uv already installed: $version"
        UV_BINARY=$(which uv)
        return 0
    fi
    
    log_info "Installing uv (modern Python package manager)..."
    
    # Try direct download first (more reliable in CI)
    if install_uv_direct; then
        add_uv_to_path
        add_uv_to_shell_rc
        
        # Verify installation
        if "$UV_BINARY" --version >/dev/null 2>&1; then
            local version=$("$UV_BINARY" --version 2>/dev/null | head -n1)
            log_success "uv installed successfully: $version"
            
            # Create wrapper function for current session
            eval "uv() { $UV_BINARY \"\$@\"; }"
            if ! is_ci; then
                export -f uv 2>/dev/null || true
            fi
            
            return 0
        else
            log_warn "Direct install succeeded but binary test failed"
        fi
    fi
    
    # Fallback to official installer if direct download failed
    log_warn "Direct download failed, trying official installer..."
    if install_uv_official; then
        add_uv_to_path
        add_uv_to_shell_rc
        
        # Create wrapper function
        eval "uv() { $UV_BINARY \"\$@\"; }"
        if ! is_ci; then
            export -f uv 2>/dev/null || true
        fi
        
        return 0
    fi
    
    log_error "Failed to install UV with both methods"
    return 1
}

# Install pyenv (optional, for multiple Python versions)
install_pyenv() {
    local pyenv_root="${PYENV_ROOT:-$HOME/.pyenv}"
    
    if dir_exists "$pyenv_root"; then
        log_info "pyenv already installed at $pyenv_root"
        return 0
    fi
    
    log_info "Installing pyenv..."
    curl https://pyenv.run | bash
    
    # Add to bashrc if not present
    if ! is_ci && ! grep -q 'PYENV_ROOT' ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'PYENV_EOF'

# Pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
PYENV_EOF
        log_info "Added pyenv to ~/.bashrc"
    fi
    
    log_success "Installed pyenv"
}

# Wrapper to call uv (handles PATH issues)
call_uv() {
    if command_exists uv; then
        uv "$@"
    elif [ -f "$UV_BINARY" ]; then
        "$UV_BINARY" "$@"
    elif type -t uv >/dev/null 2>&1; then
        # Function wrapper exists
        uv "$@"
    else
        log_error "uv not found. Please run: install_uv"
        return 1
    fi
}

# Install tool using uv
uv_install_tool() {
    local tool_name=$1
    local install_source=$2
    local tool_bin="${3:-$HOME/.local/bin/$tool_name}"
    
    tool_bin=$(expand_path "$tool_bin")
    
    # Ensure uv is installed
    if ! command_exists uv && ! [ -f "$UV_BINARY" ]; then
        log_info "uv not found, installing..."
        install_uv
    fi
    
    # Add UV to PATH
    add_uv_to_path
    
    # Check if tool is already installed
    if file_exists "$tool_bin"; then
        log_debug "$tool_name already installed at $tool_bin"
        return 0
    fi
    
    log_info "Installing $tool_name via uv tool..."
    log_debug "Source: $install_source"
    
    # Use wrapper to call uv
    if call_uv tool install "$install_source"; then
        log_success "Installed $tool_name"
        
        # Verify installation
        if file_exists "$tool_bin" || command_exists "$tool_name"; then
            log_debug "Verified $tool_name installation"
        else
            log_warn "Tool installed but binary not found at expected location"
            log_info "Try: $tool_name --version"
        fi
        return 0
    else
        log_error "Failed to install $tool_name"
        return 1
    fi
}

# Update tool using uv
uv_upgrade_tool() {
    local tool_name=$1
    
    log_info "Upgrading $tool_name via uv tool..."
    
    if call_uv tool upgrade "$tool_name" 2>/dev/null; then
        log_success "Upgraded $tool_name"
        return 0
    else
        log_warn "Failed to upgrade $tool_name (may not be installed)"
        return 1
    fi
}

# List all installed uv tools
uv_list_tools() {
    log_info "Listing uv tools..."
    
    add_uv_to_path
    
    if command_exists uv || [ -f "$UV_BINARY" ]; then
        call_uv tool list
    else
        log_error "uv is not installed"
        return 1
    fi
}

# Uninstall tool using uv
uv_uninstall_tool() {
    local tool_name=$1
    
    log_info "Uninstalling $tool_name via uv tool..."
    
    if call_uv tool uninstall "$tool_name"; then
        log_success "Uninstalled $tool_name"
        return 0
    else
        log_error "Failed to uninstall $tool_name"
        return 1
    fi
}

# Install Python tools from YAML using uv
python_install_from_yaml() {
    local yaml_file=$1
    local category=${2:-"python_tools"}
    
    log_info "Installing Python tools from $yaml_file using uv..."
    
    # Ensure uv is installed
    if ! command_exists uv && ! [ -f "$UV_BINARY" ]; then
        log_info "uv not found, installing..."
        install_uv
    fi
    
    # Add to PATH
    add_uv_to_path
    
    local tool_count=$(yq eval ".${category} | length" "$yaml_file")
    
    if [ "$tool_count" = "0" ] || [ "$tool_count" = "null" ]; then
        log_warn "No Python tools found in $category"
        return 0
    fi
    
    log_info "Found $tool_count Python tools to install"
    
    local failed=()
    for i in $(seq 0 $((tool_count - 1))); do
        local name=$(yq eval ".${category}[$i].name" "$yaml_file")
        local source=$(yq eval ".${category}[$i].source" "$yaml_file")
        local binary=$(yq eval ".${category}[$i].binary" "$yaml_file")
        
        # Use default binary path if not specified
        if [ "$binary" = "null" ] || [ -z "$binary" ]; then
            binary="$HOME/.local/bin/$name"
        fi
        
        if ! uv_install_tool "$name" "$source" "$binary"; then
            failed+=("$name")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to install: ${failed[*]}"
        return 1
    fi
    
    log_success "All Python tools installed successfully via uv"
}

# Update all Python tools installed via uv
python_update_all() {
    log_info "Updating all Python tools via uv..."
    
    if ! command_exists uv && ! [ -f "$UV_BINARY" ]; then
        log_error "uv is not installed"
        return 1
    fi
    
    add_uv_to_path
    
    # Get list of installed tools
    local tools=($(call_uv tool list --quiet 2>/dev/null | awk '{print $1}' || true))
    
    if [ ${#tools[@]} -eq 0 ]; then
        log_info "No uv tools installed to update"
        return 0
    fi
    
    log_info "Found ${#tools[@]} tools to update"
    
    local updated=0
    local failed=()
    
    for tool in "${tools[@]}"; do
        if uv_upgrade_tool "$tool"; then
            updated=$((updated + 1))
        else
            failed+=("$tool")
        fi
    done
    
    log_info "Updated $updated tools"
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to update: ${failed[*]}"
        return 1
    fi
    
    log_success "All Python tools updated successfully"
}

# Install Python itself using uv (if needed)
python_install_version() {
    local version=${1:-"3.12"}
    
    log_info "Installing Python $version via uv..."
    
    if ! command_exists uv && ! [ -f "$UV_BINARY" ]; then
        install_uv
    fi
    
    add_uv_to_path
    
    if call_uv python install "$version"; then
        log_success "Installed Python $version"
        return 0
    else
        log_error "Failed to install Python $version"
        return 1
    fi
}

# Create a virtual environment using uv (faster than venv)
uv_create_venv() {
    local venv_path=${1:-".venv"}
    local python_version=${2:-}
    
    venv_path=$(expand_path "$venv_path")
    
    if dir_exists "$venv_path"; then
        log_info "Virtual environment already exists at $venv_path"
        return 0
    fi
    
    log_info "Creating virtual environment at $venv_path..."
    
    add_uv_to_path
    
    local venv_cmd="call_uv venv"
    if [ -n "$python_version" ]; then
        venv_cmd="$venv_cmd --python $python_version"
    fi
    venv_cmd="$venv_cmd $venv_path"
    
    if eval "$venv_cmd"; then
        log_success "Created virtual environment at $venv_path"
        return 0
    else
        log_error "Failed to create virtual environment"
        return 1
    fi
}

# Legacy pipx wrapper (for backwards compatibility)
pipx_install_tool() {
    log_warn "Using pipx is deprecated. Migrating to 'uv tool'..."
    uv_install_tool "$@"
}

# Install pipx (legacy support, not recommended with uv)
install_pipx() {
    log_warn "pipx is being phased out in favor of 'uv tool'. Consider using uv instead."
    
    if command_exists pipx; then
        log_info "pipx already installed"
        return 0
    fi
    
    log_info "Installing pipx..."
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath
    log_success "Installed pipx"
}

