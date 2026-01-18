#!/bin/sh

# Installer script for Entware backup automation
# This script installs dependencies, downloads the backup script, and configures scheduling
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/skarusto/entwarebackup/main/test_install.sh | sh
#
# Or download and run locally:
#   chmod +x install.sh && ./install.sh

set -e

# Colors for output - only if TTY
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Configuration
BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/skarusto/entwarebackup/main/backup.sh"
BACKUP_SCRIPT_PATH="/opt/backup.sh"
TEMP_SCRIPT="/tmp/backup.sh.tmp"

echo "${BLUE}========================================${NC}"
echo "${BLUE}  Entware Backup Script Installer${NC}"
echo "${BLUE}========================================${NC}"
echo ""

# Step 1: Install dependencies
echo "${YELLOW}[1/7] Installing dependencies...${NC}"
echo "Installing curl..."
opkg update >/dev/null 2>&1 || true
opkg install curl >/dev/null 2>&1 || true
echo "${GREEN}✓ curl installed${NC}"

echo "Installing cron..."
opkg install cron >/dev/null 2>&1 || true
echo "${GREEN}✓ cron installed${NC}"
echo ""

# Step 2: Download backup script
echo "${YELLOW}[2/7] Downloading backup script from GitHub...${NC}"
if curl -f -L -o "$TEMP_SCRIPT" "$BACKUP_SCRIPT_URL" 2>/dev/null; then
    echo "${GREEN}✓ Script downloaded successfully${NC}"
else
    echo "${RED}✗ Failed to download script from GitHub${NC}"
    echo "${RED}URL: $BACKUP_SCRIPT_URL${NC}"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi
echo ""

# Verify file was downloaded
if [ ! -f "$TEMP_SCRIPT" ]; then
    echo "${RED}✗ ERROR: Script file not found at $TEMP_SCRIPT${NC}"
    exit 1
fi

# Step 3: Make script executable
echo "${YELLOW}[3/7] Making script executable...${NC}"
chmod +x "$TEMP_SCRIPT"
echo "${GREEN}✓ Script is now executable${NC}"
echo ""

# Step 4: Request user variables
echo "${YELLOW}[4/7] Configuration - Please provide the following information:${NC}"
echo ""

echo -n "${BLUE}Enter your Telegram Bot Token:${NC} "
read -r BOT_TOKEN
while [ -z "$BOT_TOKEN" ]; do
    echo -n "${RED}Bot Token cannot be empty. Please try again:${NC} "
    read -r BOT_TOKEN
done
echo ""

echo -n "${BLUE}Enter your Telegram Chat ID:${NC} "
read -r GROUP_CHAT_ID
while [ -z "$GROUP_CHAT_ID" ]; do
    echo -n "${RED}Chat ID cannot be empty. Please try again:${NC} "
    read -r GROUP_CHAT_ID
done
echo ""

echo -n "${BLUE}Enter your Router Name (e.g., Keenetic):${NC} "
read -r ROUTER_NAME
if [ -z "$ROUTER_NAME" ]; then
    ROUTER_NAME="Router"
fi
echo ""

echo "${GREEN}✓ Configuration received${NC}"
echo ""

# Step 5: Update variables in the script using awk (safer than sed for arbitrary data)
echo "${YELLOW}[5/7] Updating script with your credentials...${NC}"

# Create temporary awk script to handle the substitutions safely
awk -v bot="$BOT_TOKEN" -v chat="$GROUP_CHAT_ID" -v router="$ROUTER_NAME" '
    /^BOT_TOKEN="YOUR_BOT_TOKEN"/ { print "BOT_TOKEN=\"" bot "\""; next }
    /^GROUP_CHAT_ID="YOUR_CHAT_ID"/ { print "GROUP_CHAT_ID=\"" chat "\""; next }
    /^ROUTER_NAME="Keenetic"/ { print "ROUTER_NAME=\"" router "\""; next }
    { print }
' "$TEMP_SCRIPT" > "$TEMP_SCRIPT.new"

if [ $? -eq 0 ] && [ -f "$TEMP_SCRIPT.new" ]; then
    mv "$TEMP_SCRIPT.new" "$TEMP_SCRIPT"
    echo "${GREEN}✓ Script configuration updated${NC}"
else
    echo "${RED}✗ Failed to update script configuration${NC}"
    rm -f "$TEMP_SCRIPT" "$TEMP_SCRIPT.new"
    exit 1
fi
echo ""

# Step 6: Configure cron scheduling
echo "${YELLOW}[6/7] Configure automatic backup scheduling${NC}"
echo ""
echo "Select backup frequency:"
echo "  1) Do not configure automatic backups"
echo "  2) Every hour (cron.hourly)"
echo "  3) Daily (cron.daily)"
echo "  4) Weekly (cron.weekly)"
echo "  5) Monthly (cron.monthly)"
echo ""

echo -n "${BLUE}Enter your choice (1-5):${NC} "
read -r CRON_CHOICE

CRON_PATH=""
CRON_FREQUENCY="Not configured - Manual execution only"
FINAL_SCRIPT_PATH="$BACKUP_SCRIPT_PATH"

case "$CRON_CHOICE" in
    1)
        echo "${GREEN}✓ Automatic backups will not be scheduled${NC}"
        ;;
    2)
        CRON_PATH="/etc/cron.hourly"
        CRON_FREQUENCY="Every hour"
        ;;
    3)
        CRON_PATH="/etc/cron.daily"
        CRON_FREQUENCY="Daily"
        ;;
    4)
        CRON_PATH="/etc/cron.weekly"
        CRON_FREQUENCY="Weekly"
        ;;
    5)
        CRON_PATH="/etc/cron.monthly"
        CRON_FREQUENCY="Monthly"
        ;;
    *)
        echo "${RED}✗ Invalid choice. Skipping cron configuration.${NC}"
        ;;
esac

if [ -n "$CRON_PATH" ]; then
    FINAL_SCRIPT_PATH="$CRON_PATH/backup.sh"
    mv "$TEMP_SCRIPT" "$FINAL_SCRIPT_PATH" || exit 1
else
    mv "$TEMP_SCRIPT" "$BACKUP_SCRIPT_PATH" || exit 1
fi

chmod +x "$FINAL_SCRIPT_PATH"

if [ -n "$CRON_PATH" ]; then
    echo "${GREEN}✓ Backup script moved to $CRON_PATH${NC}"
    echo "${GREEN}✓ Cron job configured: $CRON_FREQUENCY${NC}"
fi

echo ""

# Step 7: Summary
echo "${YELLOW}[7/7] Installation Summary${NC}"
echo ""
echo "${BLUE}========================================${NC}"
echo "${GREEN}✓ Installation completed successfully!${NC}"
echo "${BLUE}========================================${NC}"
echo ""
echo "${BLUE}Installation Details:${NC}"
echo "  📁 Script location: ${GREEN}$FINAL_SCRIPT_PATH${NC}"
echo "  🤖 Router name: ${GREEN}$ROUTER_NAME${NC}"
echo "  ⏰ Backup frequency: ${GREEN}$CRON_FREQUENCY${NC}"
echo ""
echo "${BLUE}Next steps:${NC}"
echo "  • Test the backup manually: ${GREEN}$FINAL_SCRIPT_PATH${NC}"
echo "  • Check logs: ${GREEN}/opt/backup_log.log${NC}"
echo ""
echo "${BLUE}Manual execution:${NC}"
echo "  Run: ${GREEN}$FINAL_SCRIPT_PATH${NC}"
echo ""
echo "${BLUE}========================================${NC}"
