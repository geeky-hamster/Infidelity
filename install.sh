#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Installation directory
INSTALL_DIR="/opt/echowraith"
VENV_DIR="$INSTALL_DIR/venv"
WORDLISTS_DIR="$INSTALL_DIR/data/wordlists"

# Banner
echo -e "${GREEN}
═══════════════════════════════════════════════════════════════════════════
███████╗ ██████╗██╗  ██╗ ██████╗ ██╗    ██╗██████╗  █████╗ ██╗████████╗██╗  ██╗
██╔════╝██╔════╝██║  ██║██╔═══██╗██║    ██║██╔══██╗██╔══██╗██║╚══██╔══╝██║  ██║
█████╗  ██║     ███████║██║   ██║██║ █╗ ██║██████╔╝███████║██║   ██║   ███████║
██╔══╝  ██║     ██╔══██║██║   ██║██║███╗██║██╔══██╗██╔══██║██║   ██║   ██╔══██║
███████╗╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝██║  ██║██║  ██║██║   ██║   ██║  ██║
╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝
═══════════════════════════════════════════════════════════════════════════
${NC}"
echo -e "${BLUE}[ Spectral WiFi Security Framework ]${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
else
    echo -e "${RED}Unsupported package manager${NC}"
    exit 1
fi

echo -e "${GREEN}Detected package manager: ${BLUE}$PKG_MANAGER${NC}"

# Update package manager
echo -e "${YELLOW}Updating package manager...${NC}"
if [ "$PKG_MANAGER" = "apt-get" ]; then
    apt-get update
elif [ "$PKG_MANAGER" = "pacman" ]; then
    pacman -Sy
elif [ "$PKG_MANAGER" = "dnf" ]; then
    dnf check-update
fi

# Required system dependencies:
# - python3: Main interpreter
# - python3-pip/python-pip: Package manager
# - python3-venv/python-virtualenv: Environment isolation
# - aircrack-ng: Wireless security auditing
# - reaver: WPS attack utility
# - iw: For wireless interface management
# - wireless-tools: Collection of tools for wireless management
# - wget: For downloading wordlists
# - p7zip-full: For extracting wordlists

echo -e "${YELLOW}Installing required system packages...${NC}"
if [ "$PKG_MANAGER" = "apt-get" ]; then
    apt-get install -y python3 python3-pip python3-venv aircrack-ng reaver iw wireless-tools wget p7zip-full
elif [ "$PKG_MANAGER" = "pacman" ]; then
    pacman -S --noconfirm python python-pip python-virtualenv aircrack-ng reaver iw wireless_tools wget p7zip
elif [ "$PKG_MANAGER" = "dnf" ]; then
    dnf install -y python3 python3-pip python3-virtualenv aircrack-ng reaver iw wireless-tools wget p7zip p7zip-plugins
fi

# Check for wireless adapter
echo -e "${YELLOW}Checking for wireless adapters...${NC}"
if ! command -v iw &> /dev/null; then
    echo -e "${RED}Warning: 'iw' command not found. Unable to check wireless adapters.${NC}"
else
    INTERFACES=$(iw dev | grep Interface | wc -l)
    if [ "$INTERFACES" -eq 0 ]; then
        echo -e "${RED}Warning: No wireless interfaces detected. EchoWraith requires a compatible wireless adapter.${NC}"
        echo -e "${YELLOW}You can still install the tool, but it may not function properly without a wireless adapter.${NC}"
    else
        echo -e "${GREEN}Found ${INTERFACES} wireless interface(s).${NC}"
    fi
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/modules"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$WORDLISTS_DIR"

# Download and extract files
echo -e "${YELLOW}Downloading EchoWraith...${NC}"
curl -L https://github.com/geeky-hamster/EchoWraith/archive/main.tar.gz -o /tmp/echowraith.tar.gz
tar xzf /tmp/echowraith.tar.gz -C /tmp/

# Copy files to installation directory
echo -e "${YELLOW}Installing files...${NC}"
cp -r /tmp/EchoWraith-main/* "$INSTALL_DIR/"
cp -r /tmp/EchoWraith-main/modules/* "$INSTALL_DIR/modules/"

# Create Python virtual environment
echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
"$VENV_DIR/bin/pip" install --upgrade pip

# Check if requirements.txt exists
if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    echo -e "${GREEN}Installing dependencies from requirements.txt...${NC}"
    "$VENV_DIR/bin/pip" install -r "$INSTALL_DIR/requirements.txt"
else
    echo -e "${YELLOW}requirements.txt not found. Installing core dependencies...${NC}"
    # Core dependencies required by EchoWraith
    "$VENV_DIR/bin/pip" install rich>=13.7.0 scapy>=2.5.0 netifaces>=0.11.0 cryptography>=41.0.0 \
        pyroute2>=0.7.9 netaddr>=0.8.0 prompt_toolkit>=3.0.43 pycryptodomex>=3.19.0
    echo -e "${YELLOW}Note: Some functionality may be limited without full dependency set.${NC}"
fi

# Download and extract rockyou.txt
echo -e "${YELLOW}Setting up wordlists...${NC}"
if [ ! -f "$WORDLISTS_DIR/rockyou.txt" ]; then
    echo -e "${BLUE}Downloading rockyou.txt...${NC}"
    wget -q https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz -O "$WORDLISTS_DIR/rockyou.txt.gz"
    if [ $? -eq 0 ]; then
        gunzip "$WORDLISTS_DIR/rockyou.txt.gz"
        echo -e "${GREEN}Successfully downloaded and extracted rockyou.txt${NC}"
    else
        echo -e "${RED}Failed to download rockyou.txt. You can manually download it later.${NC}"
        echo -e "${YELLOW}Place it in: $WORDLISTS_DIR/rockyou.txt${NC}"
    fi
else
    echo -e "${GREEN}rockyou.txt already exists${NC}"
fi

# Create executable
echo -e "${YELLOW}Creating executable...${NC}"
cat > /usr/local/bin/echowraith << 'EOF'
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
source /opt/echowraith/venv/bin/activate
python3 /opt/echowraith/echowraith.py "$@"
EOF

chmod +x /usr/local/bin/echowraith

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf /tmp/echowraith.tar.gz /tmp/EchoWraith-main

# Create data directories
echo -e "${YELLOW}Creating data directories...${NC}"
mkdir -p "$INSTALL_DIR/data/"{handshakes,passwords,logs,scans,wps,deauth,temp,configs}
chmod -R 755 "$INSTALL_DIR"

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${YELLOW}You can now run EchoWraith by typing: ${GREEN}sudo echowraith${NC}"
echo -e "${BLUE}Installation directory: ${GREEN}$INSTALL_DIR${NC}"
echo -e "${BLUE}Wordlists directory: ${GREEN}$WORDLISTS_DIR${NC}"
echo -e "${YELLOW}Note: Make sure your wireless adapter supports monitor mode${NC}"

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
if [ -f "/usr/local/bin/echowraith" ] && [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}✓ EchoWraith is successfully installed.${NC}"
    if [ -f "$WORDLISTS_DIR/rockyou.txt" ]; then
        echo -e "${GREEN}✓ Wordlist is ready.${NC}"
    else
        echo -e "${YELLOW}⚠ Wordlist is missing. You may need to download it manually.${NC}"
    fi
else
    echo -e "${RED}× There was a problem with the installation.${NC}"
fi 