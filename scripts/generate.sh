#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

echo "Starting DIVE Protocol Build Process..."

# Check if tools are installed
if ! command -v kramdown-rfc &> /dev/null; then
    echo "Error: kramdown-rfc not found. Please run ./install.sh first."
    exit 1
fi

if ! command -v xml2rfc &> /dev/null; then
    echo "Error: xml2rfc not found. Please run ./install.sh first."
    exit 1
fi

# Run the Makefile
make all

echo "=========================================================="
echo "Build Successful!"
echo "Check the 'generated/' folder for your IETF documents."
echo "=========================================================="
