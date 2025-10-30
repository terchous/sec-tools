# Bug Bounty Tools Installer - Task Runner
# Usage: just <task>

# Default variables
config_dir := "config"
tools_yaml := config_dir + "/tools.yaml"
categories_yaml := config_dir + "/categories.yaml"
settings_yaml := config_dir + "/settings.yaml"

# List all available tasks
default:
    @just --list

# Show installation summary
summary:
    @echo "=== Bug Bounty Tools Installation Summary ==="
    @echo ""
    @echo "APT Packages:"
    @yq eval '.apt_packages | length' {{tools_yaml}}
    @echo ""
    @echo "Go Tools:"
    @yq eval '.go_tools | length' {{tools_yaml}}
    @echo ""
    @echo "Python Tools:"
    @yq eval '.python_tools | length' {{tools_yaml}}
    @echo ""
    @echo "Git Repositories:"
    @yq eval '.git_tools | length' {{tools_yaml}}
    @echo ""
    @echo "Categories:"
    @yq eval '.categories | keys | .[]' {{categories_yaml}}

# Install everything (full installation)
install-all: check-deps
    @echo "Starting full installation..."
    @bash install.sh --all

# Install only system packages
install-system: check-deps
    @echo "Installing system packages..."
    @bash install.sh --system

# Install only programming languages (Go, Python)
install-languages: check-deps
    @echo "Installing programming languages..."
    @bash install.sh --languages

# Install only Go tools
install-go-tools: check-deps
    @echo "Installing Go tools..."
    @bash install.sh --go-tools

# Install only Python tools
install-python-tools: check-deps
    @echo "Installing Python tools..."
    @bash install.sh --python-tools

# Install only wordlists
install-wordlists: check-deps
    @echo "Installing wordlists..."
    @bash install.sh --wordlists

# Install by category
install-category CATEGORY: check-deps
    @echo "Installing {{CATEGORY}} tools..."
    @bash install.sh --category {{CATEGORY}}

# Quick aliases for common categories
install-recon: (install-category "recon")
install-scanning: (install-category "scanning")
install-fuzzing: (install-category "fuzzing")
install-crawling: (install-category "crawling")
install-exploitation: (install-category "exploitation")

# Update existing tools
update: check-deps
    @echo "Updating tools..."
    @bash install.sh --update

# Clean up (Go cache, temporary files)
clean:
    @echo "Cleaning up..."
    @bash install.sh --clean

# Verify installations
verify:
    @echo "Verifying installations..."
    @bash install.sh --verify

# Show installed tools
list-installed:
    @echo "=== Installed Tools ==="
    @bash install.sh --list

# Check if dependencies are installed
check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    missing=()
    
    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing dependencies: ${missing[*]}"
        echo "Please install them first:"
        echo "  yq: sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq"
        exit 1
    fi

# Validate configuration files
validate-config:
    @echo "Validating configuration files..."
    @yq eval '.' {{tools_yaml}} > /dev/null && echo "✓ tools.yaml is valid"
    @yq eval '.' {{categories_yaml}} > /dev/null && echo "✓ categories.yaml is valid"
    @yq eval '.' {{settings_yaml}} > /dev/null && echo "✓ settings.yaml is valid"

# Show logs
logs:
    @ls -lt logs/ | head -n 5

# View latest log
view-log:
    @less $(ls -t logs/*.log | head -n 1)

# Generate tool inventory report
report:
    @echo "Generating tool inventory..."
    @bash install.sh --report

# Backup current installation
backup:
    @echo "Creating backup..."
    @tar -czf "bbtools-backup-$(date +%Y%m%d-%H%M%S).tar.gz" ~/go/bin ~/.gf ~/tools ~/wordlists 2>/dev/null || true
    @echo "Backup created"

# Add a new tool interactively
add-tool:
    @echo "Not implemented yet - manually edit config/tools.yaml"

# Search for a tool in configuration
search-tool TOOL:
    @echo "Searching for {{TOOL}}..."
    @yq eval '.go_tools[] | select(.name == "{{TOOL}}")' {{tools_yaml}} || echo "Not found in go_tools"
    @yq eval '.python_tools[] | select(.name == "{{TOOL}}")' {{tools_yaml}} || echo "Not found in python_tools"

# Show tool categories
show-categories:
    @yq eval '.categories | to_entries | .[] | .key + ": " + .value.description' {{categories_yaml}}

# Dry run - show what would be installed
dry-run:
    @echo "Performing dry run..."
    @bash install.sh --dry-run

# Development: Format YAML files
fmt:
    @echo "Formatting YAML files..."
    @yq eval '.' {{tools_yaml}} -i
    @yq eval '.' {{categories_yaml}} -i
    @yq eval '.' {{settings_yaml}} -i
    @echo "Formatted all YAML files"

# Install only uv
install-uv:
    @echo "Installing uv..."
    @bash -c 'source lib/python_installer.sh && install_uv'

# List all uv tools
list-uv-tools:
    @uv tool list

# Update all Python/uv tools
update-python:
    @echo "Updating Python tools via uv..."
    @bash -c 'source lib/python_installer.sh && python_update_all'

# Install specific Python tool
install-python-tool TOOL SOURCE:
    @echo "Installing {{TOOL}} from {{SOURCE}}..."
    @bash -c 'source lib/python_installer.sh && uv_install_tool "{{TOOL}}" "{{SOURCE}}"'

# Uninstall Python tool
uninstall-python-tool TOOL:
    @echo "Uninstalling {{TOOL}}..."
    @uv tool uninstall {{TOOL}}

# Show uv version and info
uv-info:
    @uv --version
    @echo ""
    @uv tool list