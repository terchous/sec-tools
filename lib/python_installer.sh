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

# Add UV to PATH for current session
add_uv_to_path() {
    if [[ ":$PATH:" != *":$UV_BIN:"* ]]; then
        export PATH="$UV_BIN:$PATH"
        log_debug "Added $UV_BIN to PATH for current session"
    fi
}

# Add UV to shell RC files
add_uv_to_shell_rc() {
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

# Install uv (the modern Python package installer)
install_uv() {
    # First, add to PATH if uv already exists but isn't in PATH
    if [ -f "$UV_BINARY" ]; then
        add_uv_to_path
        if command_exists uv; then
            local version=$(uv --version 2>/dev/null | head -n1)
            log_info "uv already installed: $version"
            return 0
        fi
    fi
    
    # Check if uv is in PATH (might be installed elsewhere)
    if command_exists uv; then
        local version=$(uv --version 2>/dev/null | head -n1)
        log_info "uv already installed: $version"
        return 0
    fi
    
    log_info "Installing uv (modern Python package manager)..."
    
    # Create .cargo/bin directory if it doesn't exist
    safe_mkdir "$UV_BIN"
    
    # Install uv using the official installer
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log_success "uv installation completed"
        
        # Add to PATH for current session
        add_uv_to_path
        
        # Add to shell RC files for future sessions
        add_uv_to_shell_rc
        
        # Verify installation
        if [ -f "$UV_BINARY" ]; then
            log_success "UV binary found at: $UV_BINARY"
            
            # Test if command works now
            if command_exists uv; then
                local version=$(uv --version 2>/dev/null | head -n1)
                log_success "uv installed successfully: $version"
                return 0
            else
                # Binary exists but command not found - PATH issue
                log_warn "UV binary exists but 'uv' command not in PATH"
                log_info "UV is installed at: $UV_BINARY"
                log_info "You can use it directly: $UV_BINARY --version"
                log_info "Or reload your shell: exec \$SHELL -l"
                
                # Create wrapper function for current session
                eval "uv() { $UV_BINARY \"\$@\"; }"
                export -f uv
                log_success "Created 'uv' function wrapper for current session"
                return 0
            fi
        else
            log_error "UV binary not found after installation"
            log_error "Expected location: $UV_BINARY"
            return 1
        fi
    else
        log_error "Failed to install uv"
        return 1
    fi
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
    if ! grep -q 'PYENV_ROOT' ~/.bashrc; then
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

# Install packages in a virtual environment using uv
uv_pip_install() {
    local venv_path=${1:-".venv"}
    shift
    local packages="$@"
    
    venv_path=$(expand_path "$venv_path")
    
    if ! dir_exists "$venv_path"; then
        log_error "Virtual environment not found: $venv_path"
        return 1
    fi
    
    log_info "Installing packages in $venv_path: $packages"
    
    # Activate venv and install
    source "$venv_path/bin/activate"
    
    if call_uv pip install $packages; then
        log_success "Installed packages: $packages"
        deactivate
        return 0
    else
        log_error "Failed to install packages"
        deactivate
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

