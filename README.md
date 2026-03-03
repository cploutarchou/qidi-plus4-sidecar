# QIDI Plus 4 Sidecar

Docker services for your QIDI Plus 4 3D printer - Mainsail web interface, camera streaming, and monitoring.

## What You Get

- **Mainsail** - Modern web UI for your printer (port 8080)
- **Camera Streaming** - Live video feed with automatic detection
- **Monitoring** - Metrics and AI failure detection (optional)

## Quick Start

### 1. First Time Setup

```bash
# Create config files
make init

# Configure your printer
nano .env
# Update PRINTER_IP and HOST_IP

# Start everything
make up
```

### 2. Access Mainsail

Open in your browser: **http://YOUR_HOST_IP:8080**

Example: `http://192.168.68.65:8080`

### 3. Daily Use

```bash
# Start services
make up

# View status
make ps

# View logs
make logs

# Stop everything
make down
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

## Configure Camera in Mainsail

1. Open Mainsail → **Settings** ⚙️ → **Webcams**
2. Edit your webcam:
   - **URL Stream:** `/camera/stream.mjpeg?src=qidi_plus4`
   - **URL Snapshot:** `/camera/frame.jpeg?src=qidi_plus4`
3. Save

The camera feed should now appear in Mainsail!

## Troubleshooting

### No Camera Feed?

Check camera status:

```bash
curl http://localhost:8080/camera/status
```

**Modes:**

- `physical` - USB camera connected ✅
- `external` - Using network camera URL ✅
- `fallback` - No camera detected ⚠️

### WSL2 Camera Not Working?

```powershell
# In PowerShell (Admin)
.\scripts\Manage-USBCamera.ps1 restart
```

### Wrong IP or Port?

Edit `.env` file:

```bash
nano .env

# Update these lines
PRINTER_IP=192.168.68.35    # Your printer's IP
HOST_IP=192.168.68.65       # Your computer's IP
```

Then restart:

```bash
make up
```

## Useful Commands

```bash
make ps          # Show running services
make logs        # View all logs
make logs-go2rtc # View camera logs only
make restart     # Restart services
make down        # Stop everything
make doctor      # Run diagnostics
```

## System Requirements

- **Linux** (Raspberry Pi 4/5, Ubuntu, Debian, etc.)
- **4GB RAM** minimum
- **Docker** and **Docker Compose**

**Note:** Windows users must use WSL2.

## Support

Check `docs/` folder for detailed guides:

- **USB-CAMERA-SETUP.md** - Complete camera setup guide

## License

MIT License - See [LICENSE](LICENSE) file.
