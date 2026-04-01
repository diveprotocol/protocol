#!/bin/bash

# Exit on error
set -e

echo "=========================================================="
echo "  DIVE Protocol - Environment Setup Script                "
echo "=========================================================="

# Function to check if a command exists
exists() {
  command -v "$1" >/dev/null 2>&1
}

# 1. Detect OS and install system dependencies
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "--> Linux detected. Updating and installing dependencies..."
    sudo apt-get update
    # libpango/libffi for WeasyPrint + fonts-noto/fonts-roboto for RFC PDF compliance
    sudo apt-get install -y python3-pip ruby-full build-essential \
        libpango-1.0-0 libpangoft2-1.0-0 libffi-dev shared-mime-info \
        fonts-noto-core fonts-roboto-fontface
    
    # Update font cache
    fc-cache -f
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "--> macOS detected. Checking for Homebrew..."
    if ! exists brew; then
        echo "Please install Homebrew first: https://brew.sh/"
        exit 1
    fi
    # pango/libffi for PDF rendering
    brew install python ruby make pango libffi
    echo "--> NOTE: For macOS, you may need to download 'Roboto Mono' from Google Fonts"
    echo "    if it's not already in your Font Book."
fi

# 2. Install xml2rfc with PDF support
echo "--> Installing xml2rfc with PDF extras..."
if exists pip3; then
    pip3 install --upgrade "xml2rfc[pdf]"
elif exists pip; then
    pip install --upgrade "xml2rfc[pdf]"
else
    echo "Error: pip not found."
    exit 1
fi

# 3. Install kramdown-rfc (Ruby)
echo "--> Installing kramdown-rfc (Ruby)..."
gem install kramdown-rfc --user-install

# Add Ruby gems to PATH if not already there
GEM_PATH=$(ruby -e 'print Gem.user_dir')/bin
if [[ ":$PATH:" != *":$GEM_PATH:"* ]]; then
    echo "--> Adding Ruby gems to PATH..."
    [[ -f ~/.bashrc ]] && echo "export PATH=\"\$PATH:$GEM_PATH\"" >> ~/.bashrc
    [[ -f ~/.zshrc ]] && echo "export PATH=\"\$PATH:$GEM_PATH\"" >> ~/.zshrc
    export PATH="$PATH:$GEM_PATH"
fi

# 4. Final verification
echo "=========================================================="
echo "  Verification of installed tools:                        "
echo "=========================================================="

if exists kramdown-rfc; then
    K_VER=$(kramdown-rfc --version 2>&1)
    echo "✅ kramdown-rfc: INSTALLED ($K_VER)"
else
    echo "❌ kramdown-rfc: FAILED"
fi

if exists xml2rfc; then
    X_VER=$(xml2rfc --version 2>&1)
    echo "✅ xml2rfc: INSTALLED ($X_VER)"
    
    # Check if weasyprint and fonts are detected
    if python3 -c "import weasyprint" >/dev/null 2>&1; then
        echo "✅ PDF Rendering (WeasyPrint): READY"
    else
        echo "⚠️  PDF Rendering: LIBRARIES MISSING (Check Pango/Cairo)"
    fi
else
    echo "❌ xml2rfc: FAILED"
fi

# Font check (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if fc-list | grep -qi "noto"; then
        echo "✅ IETF Fonts (Noto): DETECTED"
    else
        echo "⚠️  IETF Fonts: NOT DETECTED (PDF might fail)"
    fi
fi

echo "=========================================================="
echo "  Setup complete!                                         "
echo "  1. Restart your terminal or run: source ~/.bashrc       "
echo "  2. You can now run 'make' to generate PDF drafts.       "
echo "=========================================================="
