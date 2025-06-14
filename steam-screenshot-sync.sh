#!/bin/bash
# Steam Screenshot Web Upload Service
# Now with queued uploads and direct web service integration

STEAM_USERDATA="$HOME/.local/share/Steam/userdata"
WEB_SERVICE_ENDPOINT="https://your-web-service-upload.com" # REPLACE WITH ACTUAL ENDPOINT
QUEUE_DIR="$HOME/screenshots_queue"
FAILED_DIR="$HOME/screenshots_failed"
LOG_FILE="$HOME/screenshots_sync.log"
LOCK_FILE="/tmp/steam-sys-sync.lock"

# Find Steam user ID
user_id=$(find "$STEAM_USERDATA" -maxdepth 1 -type d -name '[1-9]*' | head -n1)
SCREENSHOT_DIR="${user_id}/760/remote"

# Create required directories
mkdir -p "$QUEUE_DIR" "$FAILED_DIR"
touch "$LOG_FILE"

# Create lock to prevent concurrent executions
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Already running. Exiting." | tee -a "$LOG_FILE"
    exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# Setup inotifywait to detect new files
inotifywait -m -e moved_to --format "%w%f" "$SCREENSHOT_DIR" | while read new_file; do    
    # Process only image files
    if [[ $new_file =~ \.(jpg|png)$ ]]; then
        filename=$(basename "$new_file")
        appid=$(echo "$new_file" | sed -n 's|.*remote/\([0-9]\+\)/screenshots/.*|\1|p')
        
        if [ -n "$appid" ]; then
            # Unique queue filename to prevent collisions
            queue_file="${appid}_$(date +%s%N)_${filename}"
            if mv "$new_file" "$QUEUE_DIR/$queue_file"; then
                echo "$(date "+%F %T"): Queued $filename (AppID:$appid)" | tee -a "$LOG_FILE"
            fi
        else
            mv "$new_file" "$QUEUE_DIR/${filename}"
            echo "$(date "+%F %T"): Queued without AppID: $filename" | tee -a "$LOG_FILE"
        fi
    fi
done &

# Upload worker (persistent loop)
while true; do
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
                mkdir -p "${FAILED_DIR}/$(date +%F)"
                mv "$queued_file" "${FAILED_DIR}/$(date +%F)/${filename}"
                echo "$(date "+%F %T"): Failed upload, moved $filename to fails" | tee -a "$LOG_FILE"
            fi
        
        # Process files without app ID
        else
            if curl -sf -F "screenshot=@$queued_file" "$WEB_SERVICE_ENDPOINT"; then
                rm -f "$queued_file"
                echo "$(date "+%F %T"): Uploaded file without AppID: $filename" | tee -a "$LOG_FILE"
            else
                mkdir -p "${FAILED_DIR}/$(date +%F)"
                mv "$queued_file" "${FAILED_DIR}/$(date +%F)/${filename}"
                echo "$(date "+%F %T"): Failed upload (no AppID), moved $filename to fails" | tee -a "$LOG_FILE"
            fi
        fi
        sleep 0.5 # Throttle uploads
    done
    sleep 5
done

# Main cleanup
wait
