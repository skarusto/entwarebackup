#!/bin/sh

# Telegram settings
BOT_TOKEN="YOUR_BOT_TOKEN"
GROUP_CHAT_ID="YOUR_CHAT_ID"

# Backup settings
BACKUP_FILE="/opt/opkg_backup_$(date +%Y%m%d).tar.gz"
BACKUP_DIR="/opt"
LOG_FILE="/opt/backup_log.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Start backup
log "Starting backup creation"

# Create backup
if tar czf "$BACKUP_FILE" -C "$BACKUP_DIR" . 2>/dev/null; then
    if [ -f "$BACKUP_FILE" ]; then
        FILE_SIZE=$(wc -c < "$BACKUP_FILE")
        FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))
        log "Backup created: $BACKUP_FILE (${FILE_SIZE_MB} MB)"
    else
        log "Error: Backup file not found after creation"
        exit 1
    fi
else
    log "Error while creating backup"
    exit 1
fi

# Check file size
MAX_SIZE_MB=50
if [ $FILE_SIZE_MB -gt $MAX_SIZE_MB ]; then
    log "Backup is too large: ${FILE_SIZE_MB} MB > ${MAX_SIZE_MB} MB"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$GROUP_CHAT_ID" \
        -d text="❌ Backup not sent: size ${FILE_SIZE_MB}MB exceeds ${MAX_SIZE_MB}MB limit" >/dev/null
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Send to Telegram
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
    -F chat_id="$GROUP_CHAT_ID" \
    -F document=@"$BACKUP_FILE" \
    -F caption="✅ Entware backup from $(date '+%d.%m.%Y')")

# Check send result
if echo "$RESPONSE" | grep -q '"ok":true'; then
    log "Backup successfully sent to Telegram"
    rm -f "$BACKUP_FILE"
else
    log "Error sending backup to Telegram: $RESPONSE"
fi
