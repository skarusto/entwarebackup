#!/bin/sh

# Telegram settings
BOT_TOKEN="YOUR_BOT_TOKEN"
GROUP_CHAT_ID="YOUR_CHAT_ID"

# Router settings
ROUTER_NAME="Keenetic"

# Backup settings
BACKUP_FILE="/opt/opkg_backup_${ROUTER_NAME}_$(date +%Y%m%d).tar.gz"
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

# Keep each upload below Telegram's file size limit (49 MB in bytes).
MAX_SIZE_BYTES=49000000
PARTS_DIR=""

cleanup_parts() {
    if [ -n "$PARTS_DIR" ]; then
        rm -rf "$PARTS_DIR"
    fi
}
trap cleanup_parts EXIT
trap 'exit 1' HUP INT TERM

send_document() {
    RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F chat_id="$GROUP_CHAT_ID" \
        -F document=@"$1" \
        -F caption="$2")
    CURL_STATUS=$?

    if [ "$CURL_STATUS" -eq 0 ] && printf '%s\n' "$RESPONSE" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
        return 0
    fi
    log "Error sending backup to Telegram (curl status $CURL_STATUS): $RESPONSE"
    return 1
}

CAPTION="✅ Entware backup from $(date '+%d.%m.%Y')"
if [ "$FILE_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    if ! command -v split >/dev/null 2>&1; then
        log "Error: split is required for large backups; archive retained: $BACKUP_FILE"
        exit 1
    fi

    # Use disk beside the backup rather than the router's RAM-backed /tmp.
    PARTS_DIR=$(mktemp -d "${BACKUP_FILE}.parts.XXXXXX") || {
        log "Error creating temporary directory; archive retained: $BACKUP_FILE"
        exit 1
    }
    PART_PREFIX="$PARTS_DIR/${BACKUP_FILE##*/}.part-"
    if ! split -b "$MAX_SIZE_BYTES" -a 4 "$BACKUP_FILE" "$PART_PREFIX"; then
        log "Error splitting backup; archive retained: $BACKUP_FILE"
        exit 1
    fi

    set -- "$PART_PREFIX"*
    TOTAL_PARTS=$#
    PART_NUMBER=0
    for PART_FILE do
        PART_NUMBER=$((PART_NUMBER + 1))
        if ! send_document "$PART_FILE" "$CAPTION (part $PART_NUMBER/$TOTAL_PARTS)"; then
            log "Upload failed at part $PART_NUMBER/$TOTAL_PARTS; archive retained: $BACKUP_FILE"
            exit 1
        fi
        log "Backup part $PART_NUMBER/$TOTAL_PARTS successfully sent to Telegram"
    done
else
    if ! send_document "$BACKUP_FILE" "$CAPTION"; then
        log "Archive retained: $BACKUP_FILE"
        exit 1
    fi
fi

log "Backup successfully sent to Telegram"
rm -f "$BACKUP_FILE"
