# Getting Started with QIDI Plus 4 Sidecar

This guide will get you up and running in 5 minutes!

## What You Need

- Computer running Linux (or WSL2 on Windows)
- Docker installed
- Your QIDI Plus 4 printer on the same network

## Step 1: Get the Code

```bash
git clone https://github.com/cploutarchou/qidi-plus4-sidecar.git
cd qidi-plus4-sidecar
```

## Step 2: Configure

```bash
# Create your config file
make init

# Edit the config
nano .env
```

**Update these two lines:**

```bash
PRINTER_IP=192.168.xxx.xxx  # Your printer's IP
HOST_IP=192.168.xxx.xxx     # Your computer's IP
```

Press **Ctrl+X**, then **Y**, then **Enter** to save.

## Step 3: Start Services

```bash
make up
```

That's it! 🎉

## Step 4: Open Mainsail

Open your browser and go to:

```
http://YOUR_HOST_IP:8080
```

Example: `http://192.168.68.65:8080`

## Camera Setup (Optional)

### USB Camera on WSL2 (Windows)

**One-time setup in PowerShell (as Admin):**

```powershell
# Install USB tool
winget install --id dorssel.usbipd-win

# Find your camera
usbipd list
# Look for your camera's BUSID (e.g., 5-4)

# Share the camera
.\scripts\Manage-USBCamera.ps1 bind
```

**Each time you start:

```powershell
# In PowerShell (Admin)
.\scripts\Manage-USBCamera.ps1 attach
```

Then in WSL:

```bash
make up
```

### USB Camera on Linux

Just plug it in! The camera is detected automatically when you run `make up`.

### Network Camera (IP Camera/RTSP)

Edit `.env` and add your camera URL:

```bash
EXTERNAL_WEBCAM_URL=rtsp://192.168.1.100:554/stream1
```

Then run `make up`.

## Configure Camera in Mainsail

1. Open Mainsail
2. Click the **⚙️ Settings** icon
3. Go to **Webcams**
4. Edit your webcam and set:
   - **URL Stream:** `/camera/stream.mjpeg?src=qidi_plus4`
   - **URL Snapshot:** `/camera/frame.jpeg?src=qidi_plus4`
5. Click **Save**

Your camera should now appear!

## Daily Commands

```bash
# Start services
make up

# Check status
make ps

# View logs
make logs

# Stop services
make down
```

## Troubleshooting

### Can't connect to Mainsail?

Check your HOST_IP is correct:

```bash
# On Linux/WSL
ip addr show | grep inet
```

Update `.env` if needed and run `make up` again.

### No camera feed?

Check camera status:

```bash
curl http://localhost:8080/camera/status
```

- `physical` = USB camera working ✅
- `fallback` = No camera detected ⚠️

### WSL2 camera issues?

Restart everything:

```powershell
# In PowerShell (Admin)
.\scripts\Manage-USBCamera.ps1 restart
```

## Need More Help?

- Full documentation: [README.md](../README.md)
- Camera setup guide: [docs/USB-CAMERA-SETUP.md](USB-CAMERA-SETUP.md)
- Issues: <https://github.com/cploutarchou/qidi-plus4-sidecar/issues>

## What's Next?

- **Monitoring:** Set up Obico for AI print failure detection
- **Metrics:** View Prometheus metrics at `http://YOUR_HOST_IP:9101/metrics`
- **Customization:** Edit `mainsail/config.json` for UI preferences

Happy printing! 🖨️✨
