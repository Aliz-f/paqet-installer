#!/bin/bash

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Auto-Setup Script...${NC}"

# ==============================================================================
# 1. Update and Upgrade System
# ==============================================================================
echo -e "${YELLOW}[Step 1] Updating and upgrading system packages...${NC}"
sudo apt update && sudo apt upgrade -y

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[Success] System updated.${NC}"
else
    echo -e "${RED}[Error] System update failed.${NC}"
    exit 1
fi

# ==============================================================================
# 2. Install Dependencies
# ==============================================================================
echo -e "${YELLOW}[Step 2] Installing dependencies...${NC}"
sudo apt install curl wget git nano vim htop net-tools unzip zip software-properties-common -y

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[Success] Dependencies installed.${NC}"
else
    echo -e "${RED}[Error] Installation failed.${NC}"
    exit 1
fi

# ==============================================================================
# 3. Port and Firewall Logic
# ==============================================================================
echo -e "${YELLOW}[Step 3] Checking Network and Firewall configuration...${NC}"

# Default port
TARGET_PORT=4443

# Function to check if a port is in use
check_port_usage() {
    if sudo netstat -tuln | grep -q ":$1 "; then
        return 0 # In use
    else
        return 1 # Free
    fi
}

# Check if port is free, otherwise ask user for new port
while check_port_usage $TARGET_PORT; do
    echo -e "${RED}[Warning] Port $TARGET_PORT is currently in use.${NC}"
    read -p "Please enter a different port to use: " TARGET_PORT
done

echo -e "${GREEN}[Check] Port $TARGET_PORT is free to use.${NC}"

# Check UFW Status
if sudo ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}[Firewall] UFW is ACTIVE. Allowing port $TARGET_PORT...${NC}"
    sudo ufw allow $TARGET_PORT/tcp
    echo -e "${GREEN}[Success] Port $TARGET_PORT allowed in UFW.${NC}"
else
    echo -e "${YELLOW}[Firewall] UFW is NOT active. Skipping firewall configuration.${NC}"
fi

# ==============================================================================
# 4. Download & Install Paqet Binary
# ==============================================================================
echo -e "${YELLOW}[Step 4] Downloading and Installing Paqet...${NC}"

ARCH=$(uname -m)
FILE_ARCH=""
LIB_PATH=""

case $ARCH in
    x86_64)
        FILE_ARCH="amd64"
        LIB_PATH="/usr/lib/x86_64-linux-gnu"
        ;;
    aarch64)
        FILE_ARCH="arm64"
        LIB_PATH="/usr/lib/aarch64-linux-gnu"
        ;;
    armv7l)
        FILE_ARCH="arm32"
        LIB_PATH="/usr/lib/arm-linux-gnueabihf"
        ;;
    *)
        echo -e "${RED}[Error] Unsupported architecture: $ARCH${NC}"
        ;;
esac

if [ -n "$FILE_ARCH" ]; then
    echo -e "${GREEN}[Info] Detected Architecture: $ARCH${NC}"
    REPO="hanselime/paqet"
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep "browser_download_url" | grep "linux" | grep "$FILE_ARCH" | cut -d '"' -f 4 | head -n 1)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}[Error] Could not find a download URL for architecture '$FILE_ARCH'.${NC}"
    else
        echo -e "${GREEN}[Info] Downloading: $DOWNLOAD_URL${NC}"
        wget -q --show-progress -O paqet.tar.gz "$DOWNLOAD_URL"

        echo -e "${YELLOW}[Info] Extracting package...${NC}"
        tar -xzf paqet.tar.gz

        # Find binary
        EXTRACTED_BIN=$(find . -maxdepth 1 -type f -name "paqet_linux_*" | head -n 1)

        if [ -n "$EXTRACTED_BIN" ]; then
            echo -e "${YELLOW}[Info] Installing $EXTRACTED_BIN to /usr/local/bin/paqet...${NC}"
            sudo mv "$EXTRACTED_BIN" /usr/local/bin/paqet
            sudo chmod +x /usr/local/bin/paqet
        else
            echo -e "${RED}[Error] Could not locate extracted binary.${NC}"
        fi
        rm paqet.tar.gz 2>/dev/null
    fi
fi

# ==============================================================================
# 5. Install Packet Libs & Fix Symlinks
# ==============================================================================
echo -e "${YELLOW}[Step 5] Installing Libpcap and configuring iptables-persistent...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt install libpcap-dev iptables-persistent -y

echo -e "${YELLOW}[Config] Checking symlink for libpcap in $LIB_PATH...${NC}"
if [ -d "$LIB_PATH" ]; then
    if [ -f "$LIB_PATH/libpcap.so" ] && [ ! -f "$LIB_PATH/libpcap.so.0.8" ]; then
        sudo ln -s "$LIB_PATH/libpcap.so" "$LIB_PATH/libpcap.so.0.8"
        echo -e "${GREEN}[Success] Symlink created.${NC}"
    fi
fi

# ==============================================================================
# 6. Refresh Shared Libraries
# ==============================================================================
echo -e "${YELLOW}[Step 6] Refreshing shared libraries (ldconfig)...${NC}"
sudo ldconfig

# ==============================================================================
# 7. Verify Installation
# ==============================================================================
echo -e "${YELLOW}[Step 7] Verifying Paqet installation...${NC}"
if paqet --help > /dev/null 2>&1; then
    echo -e "${GREEN}[Success] Paqet is installed and responding.${NC}"
else
    echo -e "${RED}[Error] Paqet command not working. Check installation.${NC}"
    exit 1
fi

# ==============================================================================
# 8. Generate and Save Secret
# ==============================================================================
echo -e "${YELLOW}[Step 8] Generating Paqet Secret...${NC}"
PAQET_SECRET=$(paqet secret)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} GENERATED SECRET: $PAQET_SECRET ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "$PAQET_SECRET" > secret.txt

# ==============================================================================
# 9. Prepare Configuration File
# ==============================================================================
echo -e "${YELLOW}[Step 9] Preparing Configuration Directory and File...${NC}"
sudo mkdir -p /etc/paqet
CONFIG_FILE="/etc/paqet/server.yaml"

if [ -f "example/server.yaml.example" ]; then
    sudo cp example/server.yaml.example $CONFIG_FILE
else
    sudo wget -q -O $CONFIG_FILE https://raw.githubusercontent.com/hanselime/paqet/master/example/server.yaml.example
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[Error] Config file creation failed.${NC}"
    exit 1
fi

# ==============================================================================
# 10. Configure server.yaml Automatically
# ==============================================================================
echo -e "${YELLOW}[Step 10] Auto-Configuring server.yaml...${NC}"

NET_INT=$(ip route | grep default | awk '{print $5}' | head -n1)
NET_IP4=$(ip -4 addr show $NET_INT | grep -oP "(?<=inet ).*(?=/)" | head -n1)
GW_IP=$(ip route | grep default | awk '{print $3}' | head -n1)
ping -c 1 -W 1 $GW_IP > /dev/null 2>&1
GW_MAC=$(ip neigh show $GW_IP | awk '{print $5}' | head -n1)
NET_IP6=$(ip -6 addr show $NET_INT scope global | grep -oP "(?<=inet6 ).*(?=/)" | head -n1)
GW_MAC6=""
if [ -n "$NET_IP6" ]; then
    GW_IP6=$(ip -6 route | grep default | awk '{print $3}' | head -n1)
    GW_MAC6=$(ip -6 neigh show $GW_IP6 | awk '{print $5}' | head -n1)
fi

# Apply SED Changes
sudo sed -i "s|addr: \":9999\"|addr: \":$TARGET_PORT\"|g" $CONFIG_FILE
sudo sed -i "s|interface: \"eth0\"|interface: \"$NET_INT\"|g" $CONFIG_FILE
sudo sed -i "s|addr: \"10.0.0.100:9999\"|addr: \"$NET_IP4:$TARGET_PORT\"|g" $CONFIG_FILE
sudo sed -i "0,/router_mac: \"aa:bb:cc:dd:ee:ff\"/s//router_mac: \"$GW_MAC\"/" $CONFIG_FILE

if [ -n "$NET_IP6" ]; then
    sudo sed -i "s|addr: \"\[::1\]:9999\"|addr: \"[$NET_IP6]:$TARGET_PORT\"|g" $CONFIG_FILE
    if [ -n "$GW_MAC6" ]; then
       sudo sed -i "s|router_mac: \"aa:bb:cc:dd:ee:ff\"|router_mac: \"$GW_MAC6\"|g" $CONFIG_FILE
    fi
else
  sudo sed -i "s|addr: \"\[::1\]:9999\"|addr: \"[::1\]:$TARGET_PORT\"|g" $CONFIG_FILE
fi

sudo sed -i "s|key: \"your-secret-key-here\"|key: \"$PAQET_SECRET\"|g" $CONFIG_FILE

echo -e "${GREEN}[Success] server.yaml configured automatically.${NC}"

# ==============================================================================
# 11. Create Systemd Service
# ==============================================================================
echo -e "${YELLOW}[Step 11] Checking and Creating Systemd Service File...${NC}"

# Check if service exists or is running
if [ -f "/etc/systemd/system/paqet.service" ] || systemctl is-active --quiet paqet; then
    echo -e "${YELLOW}[Info] Existing service found. Stopping it before update...${NC}"
    sudo systemctl stop paqet
fi

# Create/Overwrite the file
sudo bash -c 'cat > /etc/systemd/system/paqet.service <<EOF
[Unit]
Description=paqet Server
After=network.target

[Service]
ExecStart=/usr/local/bin/paqet run -c /etc/paqet/server.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

echo -e "${GREEN}[Success] Service file created/updated.${NC}"

# ==============================================================================
# 12. Start and Enable Service
# ==============================================================================
echo -e "${YELLOW}[Step 12] Starting Paqet Service...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable paqet
sudo systemctl start paqet

# ==============================================================================
# 13. Apply IPTables Rules (SAFE MODE - With Duplicate Check)
# ==============================================================================
echo -e "${YELLOW}[Step 13] Applying IPTables rules for port $TARGET_PORT...${NC}"

# Function to check if a rule exists
check_rule_exists() {
    local table=$1
    local chain=$2
    shift 2
    local rule="$@"

    # Use iptables -C to check if rule exists (returns 0 if exists, 1 if not)
    sudo iptables -t $table -C $chain $rule 2>/dev/null
    return $?
}

# Function to add rule if it doesn't exist
add_rule_if_not_exists() {
    local table=$1
    local chain=$2
    shift 2
    local rule="$@"

    if check_rule_exists $table $chain $rule; then
        echo -e "${YELLOW}[Skip] Rule already exists in $table/$chain: $rule${NC}"
    else
        sudo iptables -t $table -A $chain $rule
        echo -e "${GREEN}[Added] New rule to $table/$chain: $rule${NC}"
    fi
}

# 1. Raw Table (Bypass connection tracking for performance/obfuscation)
echo -e "${YELLOW}Checking RAW table rules...${NC}"
add_rule_if_not_exists raw PREROUTING -p tcp --dport $TARGET_PORT -j NOTRACK
add_rule_if_not_exists raw OUTPUT -p tcp --sport $TARGET_PORT -j NOTRACK

# 2. Mangle Table (Drop RST packets to prevent connection termination by kernel)
echo -e "${YELLOW}Checking MANGLE table rules...${NC}"
add_rule_if_not_exists mangle OUTPUT -p tcp --sport $TARGET_PORT --tcp-flags RST RST -j DROP

# 3. Filter Table (Allow traffic)
echo -e "${YELLOW}Checking FILTER table rules...${NC}"
add_rule_if_not_exists filter INPUT -p tcp --dport $TARGET_PORT -j ACCEPT
add_rule_if_not_exists filter OUTPUT -p tcp --sport $TARGET_PORT -j ACCEPT

# Display current rules
echo -e "${YELLOW}Current rules for port $TARGET_PORT:${NC}"
echo "--- RAW TABLE ---"
sudo iptables -t raw -L -n -v | grep $TARGET_PORT || echo "  No rules found"
echo "--- MANGLE TABLE ---"
sudo iptables -t mangle -L -n -v | grep $TARGET_PORT || echo "  No rules found"
echo "--- FILTER TABLE ---"
sudo iptables -t filter -L -n -v | grep $TARGET_PORT || echo "  No rules found"

# 4. Save Rules
if command -v netfilter-persistent > /dev/null 2>&1; then
    sudo netfilter-persistent save > /dev/null 2>&1
    echo -e "${GREEN}[Success] IPTables rules saved with netfilter-persistent.${NC}"
elif command -v iptables-save > /dev/null 2>&1; then
    sudo iptables-save > /etc/iptables/rules.v4
    echo -e "${GREEN}[Success] IPTables rules saved to /etc/iptables/rules.v4${NC}"
else
    echo -e "${YELLOW}[Warning] Could not save iptables rules permanently. Manual save required.${NC}"
fi

# 5. Restart Paqet Service to pick up environment changes
echo -e "${YELLOW}[Config] Restarting Paqet service...${NC}"
sudo systemctl restart paqet

if systemctl is-active --quiet paqet; then
    echo -e "${GREEN}[Success] Paqet service is RUNNING.${NC}"
else
    echo -e "${RED}[Error] Paqet service failed to start.${NC}"
    echo -e "${YELLOW}Check logs with: sudo journalctl -u paqet -n 20${NC}"
    exit 1
fi

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}      INSTALLATION COMPLETE & SERVER RUNNING          ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}Server Public IP : ${NC} $NET_IP4"
echo -e "${YELLOW}Port             : ${NC} $TARGET_PORT"
echo -e "${YELLOW}Secret Key       : ${NC} $PAQET_SECRET"
echo -e "${YELLOW}Architecture     : ${NC} $ARCH"
echo -e "${YELLOW}Config File      : ${NC} /etc/paqet/server.yaml"
echo -e "${GREEN}======================================================${NC}"
echo -e "You can check the service status anytime using: ${YELLOW}sudo systemctl status paqet${NC}"