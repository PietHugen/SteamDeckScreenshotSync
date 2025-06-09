#!/bin/bash
# Steam Screenshot Auto-Sync with Game Names
# Monitors Steam's default screenshot directory and uploads new screenshots
# to Google Drive with readable game names in filenames

STEAM_SCREENSHOTS="$HOME/.local/share/Steam/userdata/*/760/remote/*/screenshots/"
GDRIVE_PATH="gdrive:SteamDeck/Screenshots/"

# Cache for game names to avoid repeated API calls
declare -A GAME_CACHE

# Function to get game name from Steam App ID
get_game_name() {
    local appid=$1
    
    # Check cache first to avoid repeated API calls
    if [[ -n "${GAME_CACHE[$appid]}" ]]; then
        echo "${GAME_CACHE[$appid]}"
        return
    fi
    
    # Fetch game name from Steam Web API and cache the result
    local game_name=$(curl -s "https://store.steampowered.com/api/appdetails?appids=$appid" | jq -r ".\"$appid\".data.name" 2>/dev/null || echo "Unknown_Game_$appid")
    GAME_CACHE[$appid]="$game_name"
    echo "$game_name"
}

echo "Starting Steam screenshot monitor..."
echo "Watching: $STEAM_SCREENSHOTS"
echo "Upload destination: $GDRIVE_PATH"

# Monitor Steam's default screenshot directories for new files
inotifywait -m -r -e create --format '%w%f' $STEAM_SCREENSHOTS | while read file; do
    # Only process screenshot files (JPEG or PNG)
    if [[ "$file" == *.jpg ]] || [[ "$file" == *.png ]]; then
        sleep 1  # Brief delay to ensure file is fully written
        
        echo "New screenshot detected: $(basename "$file")"
        
        # Extract App ID from Steam's folder structure
        # Path format: ~/.local/share/Steam/userdata/[userid]/760/remote/[appid]/screenshots/
        appid=$(echo "$file" | grep -oP '(?<=remote/)\d+(?=/screenshots)')
        
        if [ -n "$appid" ]; then
            echo "App ID: $appid"
            
            # Get human-readable game name
            game_name=$(get_game_name "$appid")
            echo "Game: $game_name"
            
            # Clean game name for filename (remove spaces and special characters)
            clean_name=$(echo "$game_name" | tr ' /' '_' | tr -cd '[:alnum:]_-')
            filename=$(basename "$file")
            new_filename="${clean_name}_${filename}"
            
            echo "Uploading as: $new_filename"
            
            # Upload to Google Drive with metadata
            if rclone copy "$file" "$GDRIVE_PATH" --metadata-set "game=$game_name" --metadata-set "appid=$appid"; then
                echo "✓ Upload successful"
            else
                echo "✗ Upload failed"
            fi
        else
            echo "⚠ Could not determine App ID from path: $file"
            echo "Uploading without game name..."
            
            # Upload without game name if App ID extraction fails
            if rclone copy "$file" "$GDRIVE_PATH"; then
                echo "✓ Upload successful (no game name)"
            else
                echo "✗ Upload failed"
            fi
        fi
        
        echo "---"
    fi
done
