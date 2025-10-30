#!/bin/bash

# Source guard
if [ -n "${_GIT_INSTALLER_SH_LOADED:-}" ]; then
    return 0
fi
_GIT_INSTALLER_SH_LOADED=1

SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_LIB_DIR/core.sh"

# Clone git repository
git_clone() {
    local repo_url=$1
    local dest_path=$2
    local branch=${3:-}
    
    dest_path=$(expand_path "$dest_path")
    
    if dir_exists "$dest_path"; then
        log_debug "Repository already cloned at $dest_path"
        return 0
    fi
    
    log_info "Cloning $repo_url to $dest_path..."
    
    local clone_cmd="git clone"
    if [ -n "$branch" ]; then
        clone_cmd="$clone_cmd -b $branch"
    fi
    clone_cmd="$clone_cmd $repo_url $dest_path"
    
    if eval "$clone_cmd"; then
        log_success "Cloned repository to $dest_path"
        return 0
    else
        log_error "Failed to clone $repo_url"
        return 1
    fi
}

# Install git-based tool from YAML
git_install_from_yaml() {
    local yaml_file=$1
    local category=${2:-"git_tools"}
    
    log_info "Installing Git-based tools from $yaml_file..."
    
    local tool_count=$(yq eval ".${category} | length" "$yaml_file")
    
    if [ "$tool_count" = "0" ] || [ "$tool_count" = "null" ]; then
        log_warn "No Git tools found in $category"
        return 0
    fi
    
    local failed=()
    for i in $(seq 0 $((tool_count - 1))); do
        local name=$(yq eval ".${category}[$i].name" "$yaml_file")
        local repo=$(yq eval ".${category}[$i].repo" "$yaml_file")
        local dest=$(yq eval ".${category}[$i].dest" "$yaml_file")
        local branch=$(yq eval ".${category}[$i].branch" "$yaml_file")
        
        if [ "$branch" = "null" ]; then
            branch=""
        fi
        
        if ! git_clone "$repo" "$dest" "$branch"; then
            failed+=("$name")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Failed to install: ${failed[*]}"
        return 1
    fi
    
    log_success "All Git tools installed successfully"
}