#!/bin/bash

# Bug Bounty Tools Installer - Main Orchestrator
# Modular installation script with YAML configuration support

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all libraries
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/package_manager.sh"
source "$SCRIPT_DIR/lib/go_installer.sh"
source "$SCRIPT_DIR/lib/python_installer.sh"
source "$SCRIPT_DIR/lib/git_installer.sh"

# Configuration files
CONFIG_DIR="$SCRIPT_DIR/config"
TOOLS_YAML="$CONFIG_DIR/tools.yaml"
CATEGORIES_YAML="$CONFIG_DIR/categories.yaml"
SETTINGS_YAML="$CONFIG_DIR/settings.yaml"

# Load settings
load_settings() {
    log_info "Loading settings from $SETTINGS_YAML"
    
    export GO_VERSION=$(yq eval '.settings.go_version' "$SETTINGS_YAML")
    export TOOLS_DIR=$(expand_path $(yq eval '.settings.tools_dir' "$SETTINGS_YAML"))
    export WORDLISTS_DIR=$(expand_path $(yq eval '.settings.wordlists_dir' "$SETTINGS_YAML"))
    export IPLISTS_DIR=$(expand_path $(yq eval '.settings.iplists_dir' "$SETTINGS_YAML"))
    export GO_BIN=$(expand_path $(yq eval '.settings.go_bin' "$SETTINGS_YAML"))
    export LOG_DIR="$SCRIPT_DIR/$(yq eval '.settings.log_dir' "$SETTINGS_YAML")"
    
    log_debug "GO_VERSION=$GO_VERSION"
    log_debug "TOOLS_DIR=$TOOLS_DIR"
    log_debug "GO_BIN=$GO_BIN"
}

# Ensure critical tools are in PATH
ensure_path() {
    log_info "Ensuring critical tools are in PATH..."
    
    # Add Go bin
    if [ -d "/usr/local/go/bin" ]; then
        export PATH="/usr/local/go/bin:$PATH"
    fi
    if [ -d "$HOME/go/bin" ]; then
        export PATH="$HOME/go/bin:$PATH"
    fi
    
    # Add Cargo bin (for uv)
    if [ -d "$HOME/.cargo/bin" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    
    # Add local bin (for Python tools)
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_debug "Updated PATH: $PATH"
}

# Call in main()
main() {
    log_info "Bug Bounty Tools Installer - Starting..."
    log_info "Script directory: $SCRIPT_DIR"
    
    # Load settings
    load_settings
    
    # Ensure PATH is correct
    ensure_path
    
    # ... rest of main function
}

# Create necessary directories
setup_directories() {
    log_info "Creating necessary directories..."
    safe_mkdir "$TOOLS_DIR"
    safe_mkdir "$WORDLISTS_DIR"
    safe_mkdir "$IPLISTS_DIR"
    safe_mkdir "$LOG_DIR"
    safe_mkdir ~/.gf
    log_success "Directories created"
}

# Install system packages
install_system_packages() {
    log_info "Installing system packages..."
    pkg_update
    
    local skip_upgrade=$(yq eval '.options.skip_upgrade' "$SETTINGS_YAML")
    if [ "$skip_upgrade" != "true" ]; then
        pkg_upgrade
    fi
    
    pkg_install_from_yaml "$TOOLS_YAML" "apt_packages"
}

# Install programming languages
install_languages() {
    log_info "Installing programming languages..."
    
    # Install Go
    install_golang "$GO_VERSION"
    
    # Install uv (modern Python package manager)
    install_uv
    
    # Optionally install pyenv (only if managing multiple Python versions)
    local install_pyenv=$(yq eval '.options.install_pyenv' "$SETTINGS_YAML")
    if [ "$install_pyenv" = "true" ]; then
        install_pyenv
    fi
    
    # Install Python using uv (optional)
    local python_version=$(yq eval '.settings.python_version' "$SETTINGS_YAML")
    if [ "$python_version" != "null" ] && [ -n "$python_version" ]; then
        log_info "Installing Python $python_version via uv..."
        python_install_version "$python_version"
    fi
    
    log_success "Programming languages installed"
}

# Install Go tools
install_go_tools() {
    log_info "Installing Go tools..."
    go_install_from_yaml "$TOOLS_YAML" "go_tools"
}

# Install Python tools
install_python_tools() {
    log_info "Installing Python tools..."
    python_install_from_yaml "$TOOLS_YAML" "python_tools"
}

# Install Git-based tools
install_git_tools() {
    log_info "Installing Git-based tools..."
    git_install_from_yaml "$TOOLS_YAML" "git_tools"
    
    # Post-install commands for gf templates
    if dir_exists ~/tools/gf-temp; then
        log_info "Setting up gf templates..."
        safe_mkdir ~/.gf
        mv ~/tools/gf-temp/examples/*.json ~/.gf/ 2>/dev/null || true
        rm -rf ~/tools/gf-temp
    fi
    
    if dir_exists ~/tools/gf-patterns-temp; then
        mv ~/tools/gf-patterns-temp/*.json ~/.gf/ 2>/dev/null || true
        rm -rf ~/tools/gf-patterns-temp
    fi
}

# Download wordlists and IP lists
install_wordlists() {
    log_info "Downloading wordlists and IP lists..."
    
    # Process downloads from YAML
    local download_count=$(yq eval '.downloads | length' "$TOOLS_YAML")
    
    for i in $(seq 0 $((download_count - 1))); do
        local name=$(yq eval ".downloads[$i].name" "$TOOLS_YAML")
        local file_count=$(yq eval ".downloads[$i].files | length" "$TOOLS_YAML")
        
        log_info "Processing $name ($file_count files)..."
        
        for j in $(seq 0 $((file_count - 1))); do
            local url=$(yq eval ".downloads[$i].files[$j].url" "$TOOLS_YAML")
            local dest=$(yq eval ".downloads[$i].files[$j].dest" "$TOOLS_YAML")
            dest=$(expand_path "$dest")
            
            # Create destination directory
            safe_mkdir "$(dirname "$dest")"
            
            # Download if not exists
            if ! file_exists "$dest"; then
                safe_download "$url" "$dest"
            else
                log_debug "File already exists: $dest"
            fi
        done
    done
    
    log_success "Wordlists and IP lists installed"
}

# Install tools by category
install_by_category() {
    local category=$1
    
    log_info "Installing tools from category: $category"
    
    # Get tools in category
    local tools=($(yq eval ".categories.$category.tools[]" "$CATEGORIES_YAML"))
    
    if [ ${#tools[@]} -eq 0 ]; then
        log_error "Category '$category' not found or empty"
        return 1
    fi
    
    log_info "Found ${#tools[@]} tools in $category category"
    
    # Install each tool
    for tool in "${tools[@]}"; do
        # Check if it's a Go tool
        local go_cmd=$(yq eval ".go_tools[] | select(.name == \"$tool\") | .install" "$TOOLS_YAML")
        # Check for dependencies
        local go_deps=$(yq eval ".go_tools[] | select(.name == \"$tool\") | .dependencies[]" "$TOOLS_YAML" | xargs)
        if [ "$go_deps" != "null" ] && [ -n "$go_deps" ]; then
            go_install_tool "$tool" "$go_cmd" "$go_deps"
        fi

        if [ "$go_cmd" != "null" ] && [ -n "$go_cmd" ]; then
            go_install_tool "$tool" "$go_cmd"
            continue
        fi
        
        # Check if it's a Python tool
        local py_source=$(yq eval ".python_tools[] | select(.name == \"$tool\") | .source" "$TOOLS_YAML")
        if [ "$py_source" != "null" ] && [ -n "$py_source" ]; then
            pipx_install_tool "$tool" "$py_source"
            continue
        fi
        
        # Check if it's an APT package
        if yq eval ".apt_packages[] | select(. == \"$tool\")" "$TOOLS_YAML" | grep -q "$tool"; then
            pkg_install "$tool"
            continue
        fi
        
        log_warn "Tool '$tool' not found in configuration"
    done
    
    log_success "Category '$category' installation complete"
}

# Update existing tools
update_tools() {
    log_info "Updating installed tools..."
    
    # Update Go tools
    log_info "Updating Go tools..."
    local go_tools=($(yq eval '.go_tools[].name' "$TOOLS_YAML"))
    for tool in "${go_tools[@]}"; do
        local binary_path="$GO_BIN/$tool"
        if file_exists "$binary_path"; then
            local install_cmd=$(yq eval ".go_tools[] | select(.name == \"$tool\") | .install" "$TOOLS_YAML")
            log_info "Updating $tool..."
            eval "$install_cmd" || log_warn "Failed to update $tool"
        fi
    done
    
    log_info "Updating Python tools..."
    python_update_all
    
    # Update system packages
    log_info "Updating system packages..."
    pkg_update
    pkg_upgrade
    
    log_success "Update complete"
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."
    
    local missing=()
    
    # Check Go tools
    local go_tools=($(yq eval '.go_tools[].name' "$TOOLS_YAML"))
    for tool in "${go_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing+=("$tool (Go)")
        fi
    done
    
    # Check Python tools
    local py_tools=($(yq eval '.python_tools[].name' "$TOOLS_YAML"))
    for tool in "${py_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing+=("$tool (Python)")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
    else
        log_success "All tools verified successfully"
    fi
}

# List installed tools
list_installed_tools() {
    log_info "Listing installed tools..."
    
    echo ""
    echo "=== Go Tools ==="
    local go_tools=($(yq eval '.go_tools[].name' "$TOOLS_YAML"))
    for tool in "${go_tools[@]}"; do
        if command_exists "$tool"; then
            echo "✓ $tool"
        else
            echo "✗ $tool (not installed)"
        fi
    done
    
    echo ""
    echo "=== Python Tools ==="
    local py_tools=($(yq eval '.python_tools[].name' "$TOOLS_YAML"))
    for tool in "${py_tools[@]}"; do
        if command_exists "$tool"; then
            echo "✓ $tool"
        else
            echo "✗ $tool (not installed)"
        fi
    done
}

# Generate installation report
generate_report() {
    local report_file="installation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "Generating installation report..."
    
    {
        echo "Bug Bounty Tools Installation Report"
        echo "Generated: $(date)"
        echo "======================================"
        echo ""
        
        echo "System Information:"
        echo "  OS: $(get_os_info)"
        echo "  User: $USER"
        echo "  Home: $HOME"
        echo ""
        
        echo "Go Tools:"
        local go_tools=($(yq eval '.go_tools[].name' "$TOOLS_YAML"))
        for tool in "${go_tools[@]}"; do
            if command_exists "$tool"; then
                echo "  ✓ $tool"
            else
                echo "  ✗ $tool"
            fi
        done
        
        echo ""
        echo "Python Tools:"
        local py_tools=($(yq eval '.python_tools[].name' "$TOOLS_YAML"))
        for tool in "${py_tools[@]}"; do
            if command_exists "$tool"; then
                echo "  ✓ $tool"
            else
                echo "  ✗ $tool"
            fi
        done
        
    } > "$report_file"
    
    log_success "Report generated: $report_file"
    cat "$report_file"
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."
    go_cleanup
    log_success "Cleanup complete"
}

# Show usage
usage() {
    cat << 'USAGE'
Bug Bounty Tools Installer

Usage: ./install.sh [OPTIONS]

OPTIONS:
    --all               Install everything (default)
    --system            Install only system packages
    --languages         Install only programming languages (Go, Python)
    --go-tools          Install only Go tools
    --python-tools      Install only Python tools
    --git-tools         Install only Git-based tools
    --wordlists         Install only wordlists and IP lists
    --category NAME     Install tools from specific category
    --update            Update existing tools
    --verify            Verify installations
    --list              List installed tools
    --report            Generate installation report
    --clean             Clean up caches
    --dry-run           Show what would be installed
    --help              Show this help message

EXAMPLES:
    ./install.sh --all                    # Full installation
    ./install.sh --category recon         # Install only recon tools
    ./install.sh --go-tools               # Install only Go tools
    ./install.sh --update                 # Update existing tools

Use 'just' for easier task management:
    just install-all
    just install-recon
    just update
USAGE
}

# Main function
main() {
    log_info "Bug Bounty Tools Installer - Starting..."
    log_info "Script directory: $SCRIPT_DIR"
    
    # Load settings
    load_settings
    
    # Parse command line arguments
    local mode="${1:---all}"
    
    case "$mode" in
        --all)
            setup_directories
            install_system_packages
            install_languages
            install_go_tools
            install_python_tools
            install_git_tools
            install_wordlists
            cleanup
            log_success "Installation complete!"
            ;;
        --system)
            install_system_packages
            ;;
        --languages)
            install_languages
            ;;
        --go-tools)
            install_go_tools
            ;;
        --python-tools)
            install_python_tools
            ;;
        --git-tools)
            install_git_tools
            ;;
        --wordlists)
            install_wordlists
            ;;
        --category)
            if [ -z "${2:-}" ]; then
                log_error "Category name required"
                usage
                exit 1
            fi
            install_by_category "$2"
            ;;
        --update)
            update_tools
            ;;
        --verify)
            verify_installations
            ;;
        --list)
            list_installed_tools
            ;;
        --report)
            generate_report
            ;;
        --clean)
            cleanup
            ;;
        --dry-run)
            log_info "Dry run mode - no changes will be made"
            log_info "Would install:"
            yq eval '.go_tools[].name' "$TOOLS_YAML"
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $mode"
            usage
            exit 1
            ;;
    esac
    
    log_info "Done! Check logs at: $LOG_FILE"
}

# Run main function
main "$@"
