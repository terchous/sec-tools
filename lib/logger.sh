#!/bin/bash

# Source guard - prevent multiple sourcing
if [ -n "${_LOGGER_SH_LOADED:-}" ]; then
    return 0
fi
_LOGGER_SH_LOADED=1

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_ERROR="ERROR"
readonly LOG_WARN="WARN"
readonly LOG_INFO="INFO"
readonly LOG_SUCCESS="SUCCESS"
readonly LOG_DEBUG="DEBUG"

# Log directory
LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# Logger function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Write to console with colors
    case $level in
        "$LOG_ERROR")
            echo -e "${RED}[✗]${NC} $message" >&2
            ;;
        "$LOG_WARN")
            echo -e "${YELLOW}[!]${NC} $message"
            ;;
        "$LOG_INFO")
            echo -e "${BLUE}[→]${NC} $message"
            ;;
        "$LOG_SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "$LOG_DEBUG")
            if [ "${DEBUG:-0}" = "1" ]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

# Convenience functions
log_error() { log "$LOG_ERROR" "$@"; }
log_warn() { log "$LOG_WARN" "$@"; }
log_info() { log "$LOG_INFO" "$@"; }
log_success() { log "$LOG_SUCCESS" "$@"; }
log_debug() { log "$LOG_DEBUG" "$@"; }