# QIDI Plus 4 Sidecar

Complete Docker-based sidecar solution for your QIDI Plus 4 3D printer with Mainsail web interface, camera streaming, and monitoring.

## Features

- **🖥️ Mainsail** - Modern web UI for printer control (port 8080)
- **📷 Camera Streaming** - Live video with automatic USB camera detection
- **📊 Monitoring** - Metrics and AI-powered failure detection (optional)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Camera Setup](#camera-setup)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Commands Reference](#commands-reference)
- [Support & Documentation](#support--documentation)
- [License](#license)

## Prerequisites

- **Linux** (Raspberry Pi 4/5, Ubuntu, Debian, etc.) or **macOS**
- **4GB RAM** minimum
- **Docker** and **Docker Compose**
- **Network access** - Printer and host on same network

> **Windows users:** Use WSL2 (Windows Subsystem for Linux 2)

## Installation

### Initial Setup

```bash
# Clone and initialize
make init

# Create and configure environment
nano .env
# Required settings:
# - PRINTER_IP: Your printer's local IP (e.g., 192.168.68.35)
# - HOST_IP: Your computer's local IP (e.g., 192.168.68.65)
```

## Quick Start

### First Time

```bash
make up    # Start all services
make ps    # Verify services are running
```

### Access Mainsail

Open **http://YOUR_HOST_IP:8080** in your browser

Example: `http://192.168.68.65:8080`

### Daily Use

```bash
make up          # Start services
make ps          # Check status
make logs        # View logs
make down        # Stop everything
make restart     # Restart all services
```

## Camera Setup

### Option A: USB Camera (Windows + WSL2)

**One-Time Setup (PowerShell as Admin):**

```powershell
# Install USB sharing tool
winget install --id dorssel.usbipd-win

# Share your camera (run once)
.\scripts\Manage-USBCamera.ps1 bind
```

**Daily Use (PowerShell as Admin):**

```powershell
# Attach camera to WSL
.\scripts\Manage-USBCamera.ps1 attach
```

**Then in WSL:**

```bash
# Start services (camera auto-detected)
make up
```

### Option B: USB Camera (Linux/Raspberry Pi)

Just plug in your USB camera and run:

```bash
make up
```

The camera is detected automatically!

### Option C: External Network Camera

If you have an IP camera or RTSP stream:

```bash
# Edit .env
nano .env

# Add your camera URL
EXTERNAL_WEBCAM_URL=rtsp://192.168.1.100:554/stream
# or
EXTERNAL_WEBCAM_URL=http://192.168.1.100:8080/video

# Start services
make up
```

## Configuration

### Camera Configuration in Mainsail

1. Open Mainsail → **Settings** ⚙️ → **Webcams**
2. Edit your webcam:
   - **URL Stream:** `/camera/stream.mjpeg?src=qidi_plus4`
   - **URL Snapshot:** `/camera/frame.jpeg?src=qidi_plus4`
3. Save

The camera feed should now appear in Mainsail!

### Environment Variables

Edit `.env` to customize your setup:

```bash
nano .env
```

**Key settings:**

- `PRINTER_IP` - Your printer's IP address
- `HOST_IP` - Your host computer's IP address
- `EXTERNAL_WEBCAM_URL` - (Optional) URL to external camera stream

## Troubleshooting

### No Camera Feed?

Check camera status:

```bash
curl http://localhost:8080/camera/status
```

**Camera modes:**

- `physical` - USB camera connected ✅
- `external` - Using network camera URL ✅
- `fallback` - No camera detected ⚠️

### WSL2 Camera Not Working?

```powershell
# In PowerShell (Admin)
.\scripts\Manage-USBCamera.ps1 restart
```

### Wrong IP Configuration?

1. Verify your IPs are correct:

```bash
# Check printer IP
ping 192.168.68.35

# Check your host IP
hostname -I  # Linux/Raspberry Pi
ipconfig     # Windows
ifconfig     # macOS
```

1. Update `.env`:

```bash
nano .env
# Update PRINTER_IP and HOST_IP
```

1. Restart services:

```bash
make down
make up
```

## Commands Reference

```bash
make init        # Initialize configuration
make up          # Start all services
make down        # Stop all services
make ps          # Show running services
make logs        # View all logs
make logs-go2rtc # View camera service logs only
make restart     # Restart services
make doctor      # Run diagnostics
```

## Support & Documentation

- **Getting Started:** See [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md)
- **Camera Setup Guide:** See [docs/USB-CAMERA-SETUP.md](docs/USB-CAMERA-SETUP.md)
- **Issues:** File an issue on GitHub

## License

MIT License - See [LICENSE](LICENSE) file.
