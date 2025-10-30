#!/bin/bash

# Source guard
if [ -n "${_CORE_SH_LOADED:-}" ]; then
    return 0
fi
_CORE_SH_LOADED=1

# Source logger (only if not already loaded)
SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/logger.sh"

# Error handling
set -o pipefail

# Trap errors
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "Command failed with exit code $exit_code at line $line_number"
    exit $exit_code
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if file exists (fixing your original bug)
file_exists() {
    [ -f "$1" ]
}

# Check if directory exists
dir_exists() {
    [ -d "$1" ]
}

# Expand tilde in paths
expand_path() {
    echo "${1/#\~/$HOME}"
}

# Check if tool is installed
is_installed() {
    local tool_name=$1
    local check_path=$2
    
    if [ -n "$check_path" ]; then
        local expanded_path=$(expand_path "$check_path")
        file_exists "$expanded_path"
    else
        command_exists "$tool_name"
    fi
}

# Run command with retry
retry() {
    local max_attempts=$1
    shift
    local cmd="$@"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_debug "Attempt $attempt/$max_attempts: $cmd"
        if eval "$cmd"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Create directory safely
safe_mkdir() {
    local dir=$(expand_path "$1")
    if ! dir_exists "$dir"; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Safe download with retry
safe_download() {
    local url=$1
    local output=$2
    local max_retries=${3:-3}
    
    log_info "Downloading: $url"
    retry "$max_retries" wget -q --show-progress "$url" -O "$output"
}

# Get OS info
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Prompt for confirmation
confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    
    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}