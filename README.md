# Steam Screenshot Auto-Sync with Game Names

Automatically sync Steam Deck screenshots to Google Drive with readable game names in filenames.

## Overview

This tool monitors Steam's default screenshot directory and automatically uploads new screenshots to Google Drive, adding the game name to the filename for easy organization. Instead of cryptic filenames like `20241209142305_1.jpg`, you get readable names like `Half_Life_2_20241209142305_1.jpg`.

## Features

- **Automatic detection**: Monitors Steam's screenshot directory in real-time
- **Game name lookup**: Uses Steam's Web API to get readable game names
- **Smart caching**: Avoids repeated API calls for the same games
- **Metadata support**: Adds game name and App ID to file metadata
- **Systemd integration**: Runs automatically as a background service
- **No slowdown**: Uses individual file uploads instead of directory sync

## Prerequisites

- Linux system (tested on Steam Deck)
- `rclone` configured with Google Drive access
- `jq` for JSON parsing
- `curl` for API requests
- `systemd` (built into most Linux distributions)

### Configure rclone

If you haven't already configured rclone with Google Drive:

```bash
rclone config
# Follow the prompts to set up Google Drive
# Name your remote "gdrive" or update the script accordingly
```

## Installation

1. **Clone this repository**:
   ```bash
   git clone <your-repo-url>
   cd steam-screenshot-sync
   ```

2. **Make the script executable**:
   ```bash
   chmod +x steam-screenshot-sync.sh
   ```

3. **Create bin directory** (if it doesn't exist):
   ```bash
   mkdir -p ~/bin
   ```

4. **Copy the script**:
   ```bash
   cp steam-screenshot-sync.sh ~/bin/
   ```

5. **Install the systemd service and path unit**:
   ```bash
   cp steam-screenshot-sync.service ~/.config/systemd/user/
   cp steam-screenshot-sync.path ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable steam-screenshot-sync.path
   ```

6. **Start the path monitoring**:
   ```bash
   systemctl --user start steam-screenshot-sync.path
   ```

## Configuration

### Steam Settings

Make sure Steam is using the default screenshot location:
- Steam → Settings → In-Game → Screenshot Folder
- Should be set to default (not a custom directory)

**Screenshot Format**: The script supports both JPEG and PNG formats:
- Steam → Settings → In-Game → Screenshot Format
- Choose JPEG (smaller files) or PNG (higher quality)

### Script Configuration

Edit `~/bin/steam-screenshot-sync.sh` if needed:

```bash
# Change the Google Drive path if desired
GDRIVE_PATH="gdrive:Screenshots/"

# Steam's default screenshot location (usually doesn't need changing)
STEAM_SCREENSHOTS="$HOME/.local/share/Steam/userdata/*/760/remote/*/screenshots/"
```

## Usage

Once installed and started, the service runs automatically in the background. Simply:

1. Take screenshots in Steam games as usual (Steam button + R1 on Steam Deck)
2. Screenshots are automatically uploaded to Google Drive with game names
3. Check your Google Drive Screenshots folder

### Example Output

Original filename: `20241209142305_1.jpg`  
Uploaded as: `Half_Life_2_20241209142305_1.jpg`

## Managing the Service

```bash
# Check path monitoring status
systemctl --user status steam-screenshot-sync.path

# Check service status (runs when triggered)
systemctl --user status steam-screenshot-sync.service

# View logs
journalctl --user -u steam-screenshot-sync.service -f

# Stop path monitoring
systemctl --user stop steam-screenshot-sync.path

# Restart path monitoring
systemctl --user restart steam-screenshot-sync.path

# Disable auto-start
systemctl --user disable steam-screenshot-sync.path

# Manually trigger the sync (for testing)
systemctl --user start steam-screenshot-sync.service
```

## Troubleshooting

### Service won't start
```bash
# Check for errors
journalctl --user -u steam-screenshot-sync.path
journalctl --user -u steam-screenshot-sync.service

# Verify script permissions
ls -la ~/bin/steam-screenshot-sync.sh

# Test script manually
~/bin/steam-screenshot-sync.sh

# Check if path monitoring is active
systemctl --user is-active steam-screenshot-sync.path
```

### Screenshots not uploading
1. **Check rclone configuration**:
   ```bash
   rclone lsd gdrive:
   ```

2. **Verify Steam screenshot location**:
   ```bash
   ls ~/.local/share/Steam/userdata/*/760/remote/*/screenshots/
   ```

3. **Test API access**:
   ```bash
   curl -s "https://store.steampowered.com/api/appdetails?appids=440"
   ```

### Game names showing as "Unknown_Game_XXXXX"
- The game might not be in Steam's public database
- API might be temporarily unavailable
- Check internet connection

## How It Works

1. **systemd path unit** monitors Steam's userdata directory for any modifications
2. When changes are detected, the **service unit** is triggered automatically
3. The script scans for recent screenshot files (`.jpg` or `.png`) and extracts the **App ID** from the folder path
4. The **Steam Web API** is queried to get the human-readable game name
5. Game names are **cached** to avoid repeated API calls
6. The file is uploaded to Google Drive with the game name prefixed to the filename
7. **Metadata** (game name and App ID) is added to the uploaded file

This approach uses systemd's built-in file monitoring instead of `inotify-tools`, making it more suitable for immutable systems like SteamOS.

## File Structure

```
steam-screenshot-sync/
├── README.md
├── steam-screenshot-sync.sh          # Main script
├── steam-screenshot-sync.service     # Systemd service file (triggered by path unit)
└── steam-screenshot-sync.path        # Systemd path unit (monitors for changes)
```

## Contributing

Feel free to submit issues and pull requests. Some ideas for improvements:

- Support for other cloud storage providers
- Configurable filename formats
- Batch processing for rapid screenshots
- Alternative game detection methods
- Support for other gaming platforms

## License

[Add your preferred license here]

## Acknowledgments

- Steam Web API for game information
- rclone for cloud storage sync
- inotify-tools for file system monitoring
