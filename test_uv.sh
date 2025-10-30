#!/bin/bash

source lib/python_installer.sh

echo "=== Testing UV Installation ==="
echo ""

# Install uv
install_uv

echo ""
echo "=== UV Info ==="
uv --version
uv python list 2>/dev/null || echo "No Python versions managed by uv yet"

echo ""
echo "=== Installing test tool (httpie) ==="
uv_install_tool "httpie" "httpie"

echo ""
echo "=== Listing UV tools ==="
uv tool list

echo ""
echo "=== Testing httpie ==="
if command -v http >/dev/null 2>&1; then
    echo "✓ httpie installed successfully"
    http --version
else
    echo "✗ httpie installation failed"
fi

echo ""
echo "=== Cleanup test tool ==="
if confirm "Remove httpie test installation?" "y"; then
    uv_uninstall_tool "httpie"
fi

echo ""
echo "Test complete!"
