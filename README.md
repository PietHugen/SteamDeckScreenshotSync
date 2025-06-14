# Steam Screenshot Web Upload Service

Automatically upload Steam Deck screenshots to a web service with AppID metadata using event-based triggers

## Key Features

- ✔️ Automatic detection of new screenshots
- 🎮 AppID metadata extraction
- 🌐 Direct web service uploads with curl
- 🚦 Path-based triggering (no polling)
- ⚡ Systemd service for reliability
- 🔒 File locking to prevent conflicts
- 📊 Failed upload tracking with automatic retries

## Prerequisites

- Steam Deck running SteamOS or Linux with systemd
- `curl` installed (should be preinstalled on Steam Deck)
- Web service endpoint (configured in script)

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

1. **Edit the script configuration**:
   - Open `steam-screenshot-sync.sh`
   - Replace `WEB_SERVICE_ENDPOINT="https://your-web-service-upload.com"`
     with your actual upload URL
   - (Optional) Add authentication headers if needed (eg. `-H "Authorization: Bearer TOKEN"`)

2. **Make script executable and install**:
   ```bash
   chmod +x steam-screenshot-sync.sh
   cp steam-screenshot-sync.sh ~/bin/
   ```

## Activation

```bash
systemctl --user daemon-reload
systemctl --user enable --now steam-screenshot-sync.path
```

## Usage

1. Take screenshots normally (Steam + R1)
2. Screenshots will be:
   - Added to local queue (`~/screenshots_queue`)
   - Uploaded to your web service
   - Tagged with Steam AppID in filename
3. Check logs: `tail -f ~/screenshots_sync.log`

## Service Management

| Command | Description |
|---------|-------------|
| `systemctl --user status steam-screenshot-sync.path` | Monitor trigger status |
| `journalctl --user -u steam-screenshot-sync.service -f` | View live logs |
| `systemctl --user restart steam-screenshot-sync.service` | Restart processor |

## File Structure

- `~/screenshots_queue`: Pending uploads
- `~/screenshots_failed`: Failed uploads (organized by date)
- `~/.last-screenshot-sync`: Timestamp of last run
- `~/screenshots_sync.log`: Operation logs

## Testing

```bash
# Simulate a screenshot capture
mkdir -p ~/.local/share/Steam/userdata/dummy/760/remote/123/screenshots/
touch ~/.local/share/Steam/userdata/dummy/760/remote/123/screenshots/test.jpg

# Force trigger processing
systemctl --user start steam-screenshot-sync.service
```

## Troubleshooting

### Uploads not working
1. Verify endpoint configuration in script
2. Test manual curl upload:
   ```bash
   curl -F "screenshot=@test.jpg" -F "appid=123" "$WEB_ENDPOINT"
   ```
3. Check service logs:
   ```bash
   journalctl --user -u steam-screenshot-sync.service -n 20
   ```

### Path not triggering
1. Verify screenshots.vdf path matches your SteamID:
   ```bash
   ls ~/.local/share/Steam/userdata/*/760/screenshots.vdf
   ```
2. Update path unit if needed

## Technical Details

- **Trigger**: `~/.local/share/Steam/userdata/*/760/screenshots.vdf` changes
- **Processing**:
  - Only files modified since last run
  - AppID extracted from directory structure
  - Unique filenames prevent conflicts
- **Upload**:
  - Form-data POST request
  - Throttled to avoid flooding
  - AppID included in upload metadata
- **Lockfile**: `/tmp/steam-sys-sync.lock`
