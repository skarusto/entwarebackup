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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
opkg install curl >/dev/null 2>&1
echo "${GREEN}✓ curl installed${NC}"

echo "Installing cron..."
opkg install cron >/dev/null 2>&1
echo "${GREEN}✓ cron installed${NC}"
echo ""

# Step 2: Download backup script
echo "${YELLOW}[2/7] Downloading backup script from GitHub...${NC}"
if curl -f -L -o "$TEMP_SCRIPT" "$BACKUP_SCRIPT_URL" 2>/dev/null; then
    echo "${GREEN}✓ Script downloaded successfully${NC}"
else
    echo "${RED}✗ Failed to download script from GitHub${NC}"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi
echo ""

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

# Step 5: Update variables in the script
echo "${YELLOW}[5/7] Updating script with your credentials...${NC}"

# Escape special characters for sed using | as delimiter instead of /
BOT_TOKEN_ESC=$(printf '%s\n' "$BOT_TOKEN" | sed -e 's/[|&\]/\\&/g')
GROUP_CHAT_ID_ESC=$(printf '%s\n' "$GROUP_CHAT_ID" | sed -e 's/[|&\]/\\&/g')
ROUTER_NAME_ESC=$(printf '%s\n' "$ROUTER_NAME" | sed -e 's/[|&\]/\\&/g')

sed -i "s|BOT_TOKEN=\"YOUR_BOT_TOKEN\"|BOT_TOKEN=\"$BOT_TOKEN_ESC\"|" "$TEMP_SCRIPT"
sed -i "s|GROUP_CHAT_ID=\"YOUR_CHAT_ID\"|GROUP_CHAT_ID=\"$GROUP_CHAT_ID_ESC\"|" "$TEMP_SCRIPT"
sed -i "s|ROUTER_NAME=\"Keenetic\"|ROUTER_NAME=\"$ROUTER_NAME_ESC\"|" "$TEMP_SCRIPT"

echo "${GREEN}✓ Script configuration updated${NC}"
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
    mv "$TEMP_SCRIPT" "$FINAL_SCRIPT_PATH"
else
    mv "$TEMP_SCRIPT" "$BACKUP_SCRIPT_PATH"
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
