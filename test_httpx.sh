#!/bin/bash

source lib/core.sh
source lib/go_installer.sh

# Test httpx installation
echo "=== Testing httpx Installation ==="
echo ""

# Check if Python httpx exists
if command -v httpx >/dev/null 2>&1; then
    echo "Found httpx in PATH: $(which httpx)"
fi

# Check if Go httpx exists
GO_HTTPX="$HOME/go/bin/httpx"
if [ -f "$GO_HTTPX" ]; then
    echo "Found Go httpx at: $GO_HTTPX"
else
    echo "Go httpx not found at: $GO_HTTPX"
fi

echo ""
echo "Testing go_install_tool for httpx..."
go_install_tool "httpx" "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest" "$GO_HTTPX"

echo ""
echo "Verification:"
if [ -f "$GO_HTTPX" ]; then
    echo "✓ Go httpx successfully installed at: $GO_HTTPX"
    echo "Version: $($GO_HTTPX -version 2>&1 | head -n1 || echo 'unknown')"
else
    echo "✗ Go httpx installation failed"
fi