#!/bin/bash

# Source guard
if [ -n "${_PYTHON_INSTALLER_SH_LOADED:-}" ]; then
    return 0
fi
_PYTHON_INSTALLER_SH_LOADED=1

SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/core.sh"

# Install pyenv
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

# Install pipx
install_pipx() {
    if command_exists pipx; then
        log_info "pipx already installed"
        return 0
    fi
    
    log_info "Installing pipx..."
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath
    log_success "Installed pipx"
}

# Install pipx tool
pipx_install_tool() {
    local tool_name=$1
    local install_source=$2
    
    if pipx list 2>/dev/null | grep -q "$tool_name"; then
        log_debug "$tool_name already installed via pipx"
        return 0
    fi
    
    log_info "Installing $tool_name via pipx..."
    if pipx install "$install_source"; then
        log_success "Installed $tool_name"
        return 0
    else
        log_error "Failed to install $tool_name"
        return 1
    fi
}

# Install Python tools from YAML
python_install_from_yaml() {
    local yaml_file=$1
    local category=${2:-"python_tools"}
    
    log_info "Installing Python tools from $yaml_file..."
    
    # Ensure pipx is installed
    if ! command_exists pipx; then
        install_pipx
    fi
    
    local tool_count=$(yq eval ".${category} | length" "$yaml_file")
    
    if [ "$tool_count" = "0" ] || [ "$tool_count" = "null" ]; then
        log_warn "No Python tools found in $category"
        return 0
    fi
    
    local failed=()
    for i in $(seq 0 $((tool_count - 1))); do
        local name=$(yq eval ".${category}[$i].name" "$yaml_file")
        local source=$(yq eval ".${category}[$i].source" "$yaml_file")
        
        if ! pipx_install_tool "$name" "$source"; then
            failed+=("$name")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to install: ${failed[*]}"
        return 1
    fi
    
    log_success "All Python tools installed successfully"
}