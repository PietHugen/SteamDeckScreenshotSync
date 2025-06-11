# Steam Screenshot to Google Drive Sync

Automatically upload Steam Deck screenshots to Google Drive with game names in filenames without manual intervention

## Key Features

- ✔️ Automatic detection of new screenshots
- 🎮 Game name lookup via Steam API
- ☁️ Google Drive uploads with metadata
- ⚡ Systemd service for reliability
- 🔒 File locking to prevent conflicts
- 📦 API response caching for performance

## Prerequisites

- Steam Deck running SteamOS or Linux with systemd
- Install required tools:
  ```bash
  # Install jq for JSON parsing
  sudo pacman -S jq
  
  # Install rclone for Google Drive sync using precompiled binary
  sudo -v ; curl https://rclone.org/install.sh | sudo bash
  ```

## Installation

```bash
# Download repository
git clone https://github.com/PietHugen/SteamDeckScreenshotSync.git
cd Steam-Deck-Screenshot-Sync

# Create systemd directory (if needed)
mkdir -p ~/.config/systemd/user/

# Copy systemd units
cp steam-screenshot-sync.* ~/.config/systemd/user/
```

## Configuration

1. Setup rclone with Google Drive:
   ```bash
   rclone config
   ```
   Name your remote `gdrive` or update the script*

2. Make script executable and install:
   ```bash
   chmod +x steam-screenshot-sync.sh
   sudo cp steam-screenshot-sync.sh /usr/local/bin/
   ```

## Activation

```bash
systemctl --user daemon-reload
systemctl --user enable --now steam-screenshot-sync.path
```

## Usage

1. Take screenshots normally (Steam + R1)
2. Screenshots auto-upload to Google Drive:
   - Filename pattern: `Cyberpunk_2077_202405201200_1.jpg`
   - Metadata includes game name and App ID

## Service Management

| Command | Description |
|---------|-------------|
| `systemctl --user status steam-screenshot-sync.path` | Monitor status |
| `journalctl --user -u steam-screenshot-sync.service -f` | Live log view |
| `systemctl --user restart steam-screenshot-sync.service` | Force restart |

## Testing

```bash
# Trigger manual upload
systemctl --user start steam-screenshot-sync.service

# Simulate screenshot (DEBUG)
touch ~/.local/share/Steam/userdata/*/760/remote/*/screenshots/test.jpg
```

## Troubleshooting

### Uploads not working
1. Verify rclone config:
   ```bash
   rclone ls gdrive:
   ```
2. Check active service:
   ```bash
   systemctl --user is-active steam-screenshot-sync.path
   ```

### Game names missing
Test API access:
```bash
curl -s "https://store.steampowered.com/api/appdetails?appids=240"
```

## Technical Notes

- Monitors: `~/.local/share/Steam/userdata/*/760/screenshots.vdf`
- Uploads to: `gdrive:SteamDeck/Screenshots/`
- Lockfile: `/tmp/steam-screenshot-sync.lock`

---
*For Google Drive setup help see [Rclone Docs](https://rclone.org/drive/)*
