#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Installing VLCLI..."

# Check if zig is installed
if ! command -v zig &> /dev/null; then
    echo -e "${RED}Error: zig is not installed${NC}"
    echo "Please install zig first: https://ziglang.org/download/"
    exit 1
fi

# Build the project
echo "Building project..."
zig build -Doptimize=ReleaseSafe

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Create config files if they don't exist
echo "Setting up configuration files..."
[ ! -f env_config.zig ] && cp env_config.zig.template env_config.zig
[ ! -f endpoint_config.zig ] && cp endpoint_config.zig.template endpoint_config.zig
[ ! -f .env ] && cp .env.example .env

# Ask user where to install the binary
echo -e "\nWhere would you like to install vlcli?"
echo "1) /usr/local/bin (requires sudo)"
echo "2) ~/bin (user-specific)"
read -p "Select option (1/2): " install_option

SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

case $install_option in
    1)
        echo "Installing to /usr/local/bin..."
        sudo ln -sf "$(pwd)/zig-out/bin/vlcli" /usr/local/bin/vlcli
        echo -e "\n${GREEN}Installation complete!${NC}"
        echo "You can now use 'vlcli' from anywhere"
        ;;
    2)
        echo "Installing to ~/bin..."
        mkdir -p ~/bin
        ln -sf "$(pwd)/zig-out/bin/vlcli" ~/bin/vlcli

        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
            if [ -n "$SHELL_CONFIG" ]; then
                echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_CONFIG"
                echo -e "${YELLOW}Added ~/bin to PATH in $SHELL_CONFIG${NC}"
                echo -e "${YELLOW}To use vlcli in this terminal, run:${NC}"
                echo -e "${GREEN}export PATH=\"\$HOME/bin:\$PATH\"${NC}"
                echo -e "${YELLOW}Or open a new terminal window${NC}"
            else
                echo -e "${RED}Could not find shell config file (.zshrc or .bashrc)${NC}"
                echo "Please manually add to your PATH:"
                echo 'export PATH="$HOME/bin:$PATH"'
            fi
        fi

        # Add current session PATH
        export PATH="$HOME/bin:$PATH"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Edit your .env file with your API credentials"
echo -e "2. Try it out with: ${GREEN}vlcli -h${NC}"

# Verify installation
if command -v vlcli &> /dev/null; then
    echo -e "\n${GREEN}vlcli is now available in your current terminal${NC}"
else
    echo -e "\n${YELLOW}Note: You might need to open a new terminal or run:${NC}"
    echo -e "${GREEN}export PATH=\"\$HOME/bin:\$PATH\"${NC}"
fi
