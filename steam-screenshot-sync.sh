#!/bin/bash
# Steam Screenshot Web Upload Service
# Path-triggered version without polling

STEAM_USERDATA="$HOME/.local/share/Steam/userdata"
WEB_SERVICE_ENDPOINT="https://your-web-service-upload.com" # REPLACE WITH ACTUAL ENDPOINT
QUEUE_DIR="$HOME/screenshots_queue"
FAILED_DIR="$HOME/screenshots_failed"
LOG_FILE="$HOME/screenshots_sync.log"
LOCK_FILE="/tmp/steam-sys-sync.lock"
TIMESTAMP_FILE="$HOME/.last-screenshot-sync"

# Find Steam user ID
user_id=$(find "$STEAM_USERDATA" -maxdepth 1 -type d -name '[1-9]*' | head -n1)
SCREENSHOT_DIR="${user_id}/760/remote"

# Create required directories
mkdir -p "$QUEUE_DIR" "$FAILED_DIR"
touch "$LOG_FILE"

# Create lock to prevent concurrent executions
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "$(date "+%F %T"): Already running. Exiting." | tee -a "$LOG_FILE"
    exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# Get last successful run time
if [ -f "$TIMESTAMP_FILE" ]; then
    last_run=$(<"$TIMESTAMP_FILE")
else
    last_run=0
fi
current_time=$(date +%s)

echo "$(date "+%F %T"): Processing new screenshots (since $last_run)" | tee -a "$LOG_FILE"

# Create temporary timestamp file for find command
tmp_timestamp=$(mktemp)
touch -d "@$last_run" "$tmp_timestamp"

# Find and move new screenshots to queue
find "$SCREENSHOT_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) -newer "$tmp_timestamp" -print0 | while read -r -d $'\0' new_file; do
    filename=$(basename "$new_file")
    appid=$(echo "$new_file" | sed -n 's|.*remote/\([0-9]\+\)/screenshots/.*|\1|p')
    
    if [ -n "$appid" ]; then
        queue_file="${appid}_$(date +%s%N)_${filename}"
        if mv "$new_file" "$QUEUE_DIR/$queue_file"; then
            echo "$(date "+%F %T"): Queued $filename (AppID:$appid)" | tee -a "$LOG_FILE"
        fi
    else
        if mv "$new_file" "$QUEUE_DIR/${filename}"; then
            echo "$(date "+%F %T"): Queued without AppID: $filename" | tee -a "$LOG_FILE"
        fi
    fi
done
rm -f "$tmp_timestamp"

# Process all queued files
for queued_file in "$QUEUE_DIR"/*; do
    [ -e "$queued_file" ] || continue
    filename=$(basename "$queued_file")
    appid=$(echo "$filename" | sed -n 's/^\([0-9]\+\)_.*/\1/p')
    
    # Process file with app ID
    if [[ "$appid" =~ ^[0-9]+$ ]]; then
        if curl -sf -F "screenshot=@$queued_file" -F "appid=$appid" "$WEB_SERVICE_ENDPOINT"; then
            echo "$(date "+%F %T"): Uploaded $filename" | tee -a "$LOG_FILE"
            rm -f "$queued_file"
        else
            failed_dir="${FAILED_DIR}/$(date +%F)"
            mkdir -p "$failed_dir"
            mv "$queued_file" "$failed_dir/${filename}"
            echo "$(date "+%F %T"): Failed upload, moved $filename to $failed_dir" | tee -a "$LOG_FILE"
        fi
    
    # Process files without app ID
    else
        if curl -sf -F "screenshot=@$queued_file" "$WEB_SERVICE_ENDPOINT"; then
            rm -f "$queued_file"
            echo "$(date "+%F %T"): Uploaded file without AppID: $filename" | tee -a "$LOG_FILE"
        else
            failed_dir="${FAILED_DIR}/$(date +%F)"
            mkdir -p "$failed_dir"
            mv "$queued_file" "$failed_dir/${filename}"
            echo "$(date "+%F %T"): Failed upload (no AppID), moved $filename to $failed_dir" | tee -a "$LOG_FILE"
        fi
    fi
    sleep 0.2  # Avoid flooding the server
done

# Update success time
echo "$current_time" > "$TIMESTAMP_FILE"
echo "$(date "+%F %T"): Finished processing" | tee -a "$LOG_FILE"

exit 0
