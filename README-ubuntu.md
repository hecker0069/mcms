# Ubuntu Installer for Termux

Install a full Ubuntu Linux environment on your Android device via Termux.

## Quick Start

```bash
# In Termux
chmod +x ubuntu-termux.sh
./ubuntu-termux.sh
```

## Installation Options

| Command | Description |
|---------|-------------|
| `./ubuntu-termux.sh` | Interactive menu |
| `./ubuntu-termux.sh --quick` | Quick install with defaults |
| `./ubuntu-termux.sh --gui` | Install with XFCE desktop |

## After Installation

### Enter Ubuntu
```bash
proot-distro login ubuntu
# or use the alias
ubuntu
```

### Exit Ubuntu
```bash
exit
```

### File Access (inside Ubuntu)
- Termux home: `/home/termux`
- SD card: `/sdcard`

## GUI Mode (Optional)

If you installed with `--gui`:

1. Enter Ubuntu: `ubuntu`
2. Start VNC server: `vncserver :1`
3. Set password on first run
4. Connect with any VNC viewer to `localhost:5901`

## What Gets Installed

- Ubuntu 22.04 LTS (arm64)
- proot-distro for container management
- Basic tools: sudo, nano, vim, curl, wget, git, htop
- Optional: XFCE4 desktop + VNC server

## Requirements

- Termux app on Android
- ~1GB free storage (~2GB with GUI)
- Internet connection for download

## Troubleshooting

**"Permission denied"**
```bash
chmod +x ubuntu-termux.sh
```

**Slow performance**
- This is normal for proot emulation
- Close other apps to free RAM

**Network issues inside Ubuntu**
```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

## Uninstall

```bash
./ubuntu-termux.sh
# Select option 3 (Remove Ubuntu)
```

Or manually:
```bash
proot-distro remove ubuntu
```
