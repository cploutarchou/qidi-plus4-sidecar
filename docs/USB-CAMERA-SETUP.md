# USB Camera Setup Guide

Complete guide for setting up a USB camera with QIDI Plus 4 Sidecar.

> Looking for all guides? See [Documentation](README.md).

## Linux / Raspberry Pi

**It just works!** 🎉

Plug in your USB camera and run:

```bash
make up
```

The camera is detected automatically.

---

## Windows (WSL2)

### One-Time Setup

#### Step 1: Install usbipd-win

In **PowerShell (as Administrator)**:

```powershell
winget install --id dorssel.usbipd-win
```

Close and reopen PowerShell after installation.

#### Step 2: Find Your Camera

In **PowerShell (as Administrator)**:

```powershell
usbipd list
```

Look for your camera in the list. Note its **BUSID** (example: `5-4`).

#### Step 3: Configure Camera BUSID

Edit `.env` file in the project:

```bash
USB_CAMERA_BUSID=5-4
USB_CAMERA_NAME=YourCamera
```

#### Step 4: Bind (Share) the Camera

In **PowerShell (as Administrator)**:

```powershell
cd C:\path\to\qidi-plus4-sidecar
.\scripts\Manage-USBCamera.ps1 bind
```

This only needs to be done **once**!

### Daily Use

Each time you start Windows or restart WSL:

#### Step 1: Attach Camera to WSL

In **PowerShell (as Administrator)**:

```powershell
cd C:\path\to\qidi-plus4-sidecar
.\scripts\Manage-USBCamera.ps1 attach
```

#### Step 2: Start Services

In **WSL terminal**:

```bash
cd ~/workspace/qidi-plus4-sidecar
make up
```

### PowerShell Script Commands

The `Manage-USBCamera.ps1` script makes camera management easy:

```powershell
# Show USB device status
.\scripts\Manage-USBCamera.ps1 status

# Bind camera (one-time setup)
.\scripts\Manage-USBCamera.ps1 bind

# Attach camera to WSL2
.\scripts\Manage-USBCamera.ps1 attach

# Detach camera from WSL2
.\scripts\Manage-USBCamera.ps1 detach

# Restart WSL and re-attach camera
.\scripts\Manage-USBCamera.ps1 restart

# Show help
.\scripts\Manage-USBCamera.ps1 help
```

---

## Network Camera (Alternative)

If USB passthrough is problematic, use a network camera instead:

### Option 1: IP Camera / RTSP Stream

Edit `.env`:

```bash
EXTERNAL_WEBCAM_URL=rtsp://192.168.1.100:554/stream1
```

### Option 2: Webcam Streaming Software

Use tools like **mjpg-streamer** or **OBS** to stream your USB camera over HTTP:

```bash
# Example with mjpg-streamer on Windows
EXTERNAL_WEBCAM_URL=http://192.168.1.100:8080/video
```

Then run:

```bash
make up
```

---

## Verify Camera is Working

### Check Camera Status

```bash
curl http://localhost:8080/camera/status
```

**Response meanings:**

- `"mode":"physical"` - USB camera detected ✅
- `"mode":"external"` - Network camera in use ✅
- `"mode":"fallback"` - No camera (showing black screen) ⚠️

### Test Camera Stream

```bash
curl -I http://localhost:8080/camera/stream.mjpeg?src=qidi_plus4
```

Should return `HTTP/1.1 200 OK`.

### View in Browser

Open: `http://YOUR_HOST_IP:8080/camera/stream.mjpeg?src=qidi_plus4`

You should see your camera feed!

---

## Troubleshooting

### WSL2: Camera not showing `/dev/video*`

#### Solution 1: Restart everything

```powershell
# PowerShell (Admin)
.\scripts\Manage-USBCamera.ps1 restart
```

#### Solution 2: Check usbipd status

```powershell
usbipd list
```

Look for "Attached" in the STATE column for your camera. If it says "Not shared", run:

```powershell
.\scripts\Manage-USBCamera.ps1 bind
.\scripts\Manage-USBCamera.ps1 attach
```

### Linux: Permission denied on `/dev/video*`

Add your user to the `video` group:

```bash
sudo usermod -a -G video $USER
```

Log out and log back in.

### Mainsail shows "NO SIGNAL"

1. Check camera status: `curl http://localhost:8080/camera/status`
2. In Mainsail **Settings** → **Webcams**, update URLs:
   - Stream: `/camera/stream.mjpeg?src=qidi_plus4`
   - Snapshot: `/camera/frame.jpeg?src=qidi_plus4`

### Camera works but image is upside down

In Mainsail **Settings** → **Webcams**, enable **Flip vertically** or **Flip horizontally**.

---

## How It Works

1. **PowerShell script** manages USB sharing via usbipd-win (Windows only)
2. **Auto-attach script** checks if camera is available during `make up`
3. **Auto-detect script** finds `/dev/video*` and configures go2rtc
4. **go2rtc** captures video and streams to Mainsail
5. **nginx** proxies streams from go2rtc to Mainsail UI

---

## Configuration Reference

### `.env` Settings

```bash
# Auto-detection mode (recommended)
CAMERA_SOURCE=auto

# Force external camera only
CAMERA_SOURCE=external
EXTERNAL_WEBCAM_URL=rtsp://192.168.1.100:554/stream

# Force printer camera only
CAMERA_SOURCE=printer
PRINTER_WEBCAM_URL=http://192.168.68.35:10088/webcam/?action=stream
```

---

## Need More Help?

- Documentation hub: [README.md](README.md)
- Main project overview: [../README.md](../README.md)
- Getting started: [GETTING-STARTED.md](GETTING-STARTED.md)
- Issues: <https://github.com/cploutarchou/qidi-plus4-sidecar/issues>
