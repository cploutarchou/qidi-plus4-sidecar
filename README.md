# QIDI Plus 4 Sidecar - Container Stack

A comprehensive Docker Compose stack for QIDI Plus 4 3D printer management and monitoring with web interfaces, streaming, and AI-powered print detection.

## 📋 Overview

This project provides a complete containerized solution for your QIDI Plus 4 printer:
- **Mainsail** - Modern web UI for printer control and monitoring
- **Moonraker Exporter** - Prometheus metrics for print analytics
- **go2rtc** - Hardware-accelerated WebRTC/MJPEG streaming with NVIDIA NVENC
- **Moonraker-Obico** - AI-powered print failure detection
- **All services run locally** with no cloud dependency

## 🔧 Prerequisites

- Docker and Docker Compose installed
- QIDI Plus 4 printer on network (requires Moonraker API running)
- USB camera connected to host for streaming
- NVIDIA GPU optional (for hardware accelerated H.264 encoding)

## ⚙️ Initial Setup for Local Deployment

**Before running the containers, you must create configuration files from the provided examples.** All sensitive configuration is excluded from git (see `.gitignore`) to protect credentials and IP addresses.

### Step 1: Create Environment File

```bash
# Copy the environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

Required variables in `.env`:
- `PRINTER_IP` - Your QIDI Plus 4 printer's IP (e.g., `192.168.68.35`)
- `HOST_IP` - Your Docker host's IP (e.g., `192.168.68.26`) - Used for camera streaming
- `TZ` - Your timezone (e.g., `Europe/London`)
- `OBICO_AUTH_TOKEN` - Your Obico auth token from obico.io (optional, for AI detection)
- `OBICO_SECRET_KEY` - Generate a random secret key

Generate a secure secret key:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Step 2: Create Configuration Files from Examples

All the following files must be created. Templates with detailed documentation are provided:

#### 2.1 go2rtc Stream Configuration

```bash
# Copy the template
cp go2rtc/go2rtc.yaml.example go2rtc/go2rtc.yaml
```

Edit `go2rtc/go2rtc.yaml` if needed:
- Verify `/dev/video0` matches your USB camera device
- Adjust resolution/framerate if needed
- Configure NVIDIA NVENC settings if you have a GPU

**Verify your camera device:**
```bash
ls -la /dev/video*
# Output should show /dev/video0 or similar
```

#### 2.2 Mainsail Reverse Proxy Configuration

```bash
# Copy the template (automatically processed by docker-compose)
cp mainsail/nginx/default.conf.example mainsail/nginx/default.conf
```

**No manual editing needed!** The docker-compose.yml automatically substitutes `${PRINTER_IP}` and `${HOST_IP}` variables from your `.env` file at container startup using `envsubst`.

#### 2.3 Mainsail UI Configuration

```bash
# Copy the template (automatically processed by docker-compose)
cp mainsail/config.json.example mainsail/config.json
```

**No manual editing needed!** The docker-compose.yml automatically substitutes `${HOST_IP}` variables from your `.env` file at container startup.

#### 2.4 Obico AI Detection Configuration

```bash
# Copy the template
cp obico/moonraker-obico.cfg.example obico/moonraker-obico.cfg
```

Edit `obico/moonraker-obico.cfg` and update:
- `${OBICO_AUTH_TOKEN}` - Your Obico auth token from https://app.obico.io
- `${PRINTER_IP}` - Your printer's IP address
- `${HOST_IP}` - Docker host's IP address

### Step 3: Summary of What Was Configured

| File                          | Status   | Notes                                              |
| ----------------------------- | -------- | -------------------------------------------------- |
| `.env`                        | ✅ Manual | User fills in PRINTER_IP, HOST_IP, TZ              |
| `go2rtc/go2rtc.yaml`          | ✅ Manual | Copy from .example, adjust camera device if needed |
| `mainsail/nginx/default.conf` | ⚙️ Auto   | Automatically substituted at container startup     |
| `mainsail/config.json`        | ⚙️ Auto   | Automatically substituted at container startup     |
| `obico/moonraker-obico.cfg`   | ✅ Manual | Copy from .example, fill in auth token             |

**Manual files** need one-time setup. **Auto files** are processed by docker-compose.yml each time containers start.

### Step 4: Verify Configuration

Before starting containers, verify all files are created:

```bash
# Check all required files exist
test -f .env && echo "✓ .env exists" || echo "✗ .env missing"
test -f go2rtc/go2rtc.yaml && echo "✓ go2rtc/go2rtc.yaml exists" || echo "✗ go2rtc/go2rtc.yaml missing"
test -f mainsail/nginx/default.conf && echo "✓ mainsail/nginx/default.conf exists" || echo "✗ mainsail/nginx/default.conf missing"
test -f mainsail/config.json && echo "✓ mainsail/config.json exists" || echo "✗ mainsail/config.json missing"
test -f obico/moonraker-obico.cfg && echo "✓ obico/moonraker-obico.cfg exists" || echo "✗ obico/moonraker-obico.cfg missing"
```

All files should show ✓ before proceeding.

## 🚀 Quick Start

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f [service-name]

# Stop services
docker compose down
```

## 📦 Services

### Mainsail (Port 8080)
- Modern web UI for printer control
- Real-time status, job management, file browser
- Integrated camera feed display
- **URL**: http://localhost:8080

### Moonraker Prometheus Exporter (Port 9101)
- Metrics collection for print analytics
- Integrates with monitoring systems
- Exports printer state, temperatures, print progress

### go2rtc (Ports 8554/8555/1984)
- **MJPEG Stream**: `http://localhost:1984/api/stream.mjpeg?src=qidi_plus4`
- **H.264 RTSP**: `rtsp://localhost:8554/qidi_plus4_h264`
- **WebRTC**: Port 8555
- Hardware-accelerated encoding (NVIDIA NVENC if available)
- 1920×1080 @ 25fps MJPEG capture

### Moonraker-Obico (Local)
- AI-powered print failure detection
- Processes camera stream for anomalies
- **Note**: Requires Obico cloud account for remote monitoring

## 🔐 Configuration

### Create `.env` file (required)
```bash
cp .env.example .env
```

**Environment variables handled:**
- `PRINTER_IP` - Automatically substituted in docker-compose and all services
- `HOST_IP` - Automatically substituted for camera streaming endpoints
- `TZ` - Timezone for all services

The docker-compose.yml automatically processes these variables at startup - **no manual IP editing needed!**

### Network Configuration
All IP addresses are parameterized with safe defaults:
- Printer IP defaults to: `192.168.68.35` (QIDI Plus 4)
- Host IP defaults to: `192.168.68.26` (Docker host)
- Update these in `.env` to match your network

## 📹 Camera Setup

### For Mainsail:
1. Open http://localhost:8080
2. Camera feed displays at top of dashboard
3. Uses `uv4l-mjpeg` service in Mainsail UI

### Stream URLs:
- **Snapshot**: `http://localhost:1984/api/frame.jpeg?src=qidi_plus4`
- **MJPEG Stream**: `http://localhost:1984/api/stream.mjpeg?src=qidi_plus4`
- **H.264 Stream**: `rtsp://localhost:8554/qidi_plus4_h264`

### Camera Quality:
- Resolution: 1920×1080 (Full HD)
- Framerate: 25 fps (USB stability)
- Format: MJPEG with quality encoding
- Encoder: NVIDIA NVENC H.264 (when available)

## 🔧 Advanced Configuration

### Adjust video quality
Edit `go2rtc/go2rtc.yaml`:
```yaml
streams:
  qidi_plus4:
    - "exec:ffmpeg ... -video_size 1920x1080 -framerate 25 ..."
  qidi_plus4_h264:
    - "exec:ffmpeg ... -b:v 16M -maxrate 20M ..."
```

### Camera controls
Modify camera sensor settings (sharpness, contrast, etc.):
```bash
v4l2-ctl -d /dev/video0 --set-ctrl sharpness=200
```

## 📊 Current Status

| Component           | Status    | Notes                               |
| ------------------- | --------- | ----------------------------------- |
| Mainsail            | ✅ Working | Full printer control + camera       |
| go2rtc              | ✅ Working | 1080p @ 25fps, hardware accelerated |
| Prometheus Exporter | ✅ Working | Metrics collection active           |
| Moonraker-Obico     | ✅ Working | MJPEG stream configured             |
| Camera Stream       | ✅ Working | Full HD quality stable              |

## 🐛 Troubleshooting

### Camera not showing in Mainsail:
```bash
# Check if go2rtc is running
docker ps | grep go2rtc

# Test snapshot endpoint
curl http://localhost:1984/api/frame.jpeg?src=qidi_plus4

# View go2rtc logs
docker logs qidi_go2rtc
```

### High memory usage:
- Camera streams consume memory per client connection
- Use MJPEG for better efficiency than H.264 transcoding

### USB camera issues:
- Check device listing: `ls -la /dev/video*`
- Verify USB permissions in docker-compose.yml
- Try different framerate/resolution in go2rtc config

## 📝 File Structure

```
.
├── docker-compose.yml          # Main Compose configuration
├── go2rtc/                      # Camera streaming service
│   ├── Dockerfile.nvenc        # GPU-accelerated H.264 encoder
│   └── go2rtc.yaml            # Stream definitions
├── mainsail/                    # Web UI configuration
│   ├── config.json            # Camera and UI settings
│   └── nginx/                 # Reverse proxy config
├── obico/                       # AI failure detection
│   └── moonraker-obico.cfg    # Service configuration
└── qidi-sidecar-bootstrap.sh   # Initialization script
```

## 📄 License

This project is for personal use with a QIDI Plus 4 printer.

## 🤝 Contributing

This is a personal project but improvements welcome via local testing.

## 📞 Support

For issues with:
- **Mainsail**: See https://docs.mainsail.xyz/
- **Moonraker**: See https://moonraker.readthedocs.io/
- **go2rtc**: See https://github.com/AlexxIT/go2rtc
- **Obico**: See https://www.obico.io/

---

**Last Updated**: February 2026
  - Low-latency live streaming
  - Hardware-accelerated encoding (AMD Radeon)
  - WebRTC protocol support
- **Config File:** `./go2rtc/go2rtc.yaml`
- **Devices Used:** `/dev/video1`, `/dev/dri` (GPU)

### 5. **Moonraker Prometheus Exporter**
- **Port:** 9101
- **URL:** http://localhost:9101/metrics
- **Purpose:** Export printer metrics for monitoring
- **Metrics Include:**
  - Extruder temperature
  - Bed temperature
  - Print progress
  - Uptime and statistics

## 📁 Project Structure

```
.
├── docker-compose.yml              # Main Compose configuration
├── .env.example                    # Environment variables template
├── go2rtc/
│   ├── Dockerfile.nvenc            # GPU-accelerated H.264 encoder
│   ├── go2rtc.yaml.example         # Stream definitions template
│   └── go2rtc.yaml                 # Actual stream config (gitignored)
├── mainsail/
│   ├── config.json.example         # UI settings template
│   ├── config.json                 # Actual UI config (gitignored)
│   └── nginx/
│       ├── default.conf.example    # Reverse proxy template
│       └── default.conf            # Actual proxy config (gitignored)
├── obico/
│   ├── moonraker-obico.cfg.example # AI detection template
│   └── moonraker-obico.cfg         # Actual config (gitignored)
├── qidi-sidecar-bootstrap.sh       # Initialization script
└── README.md                        # This file
```

## 📌 Important Notes

### Configuration Files & Security
- **All configuration files with IP addresses and credentials are gitignored** (see `.gitignore`)
- **Example `.example` files are provided** - copy these to create actual configs
- **Never commit real configuration files** containing IPs, tokens, or passwords
- Files created by docker containers have rw permissions for local editing - **no sudo needed**

### Automatic Variable Substitution
- `docker-compose.yml` automatically substitutes `${PRINTER_IP}`, `${HOST_IP}`, and `${TZ}` from `.env`
- Mainsail nginx config and config.json are processed at container startup
- Changes to `.env` require container restart: `docker compose restart mainsail`

### Ports Reference

| Service             | Port       | Purpose                      |
| ------------------- | ---------- | ---------------------------- |
| Mainsail Web UI     | 8080       | Printer control & monitoring |
| go2rtc MJPEG        | 1984 (API) | Camera stream endpoint       |
| go2rtc RTSP         | 8554       | H.264 streaming              |
| go2rtc WebRTC       | 8555       | Low-latency streaming        |
| Prometheus Exporter | 9101       | Metrics for monitoring       |

## 🔧 Docker Compose Commands

```bash
# Start all services
docker compose up -d

# View real-time logs
docker compose logs -f

# View logs for specific service
docker compose logs -f mainsail

# Stop all services
docker compose down

# Restart services after .env changes
docker compose restart mainsail moonraker-exporter moonraker-obico

# View service status
docker compose ps

# Rebuild images
docker compose build --no-cache
```

## 🐛 Troubleshooting

### Printer Connection Issues
**Mainsail won't connect to printer:**
```bash
# Check printer IP (adjust PRINTER_IP in .env if different)
ping 192.168.68.35

# Verify Moonraker is running on printer
curl http://192.168.68.35:7125/server/info

# Check Docker host can reach printer
docker exec qidi_mainsail curl http://{PRINTER_IP}:7125/server/info
```

### Camera Stream Issues
**Camera not showing in Mainsail:**
```bash
# Check if go2rtc is running
docker ps | grep go2rtc

# Test snapshot endpoint
curl http://localhost:1984/api/frame.jpeg?src=qidi_plus4

# View go2rtc logs
docker logs qidi_go2rtc

# Verify camera device exists
ls -la /dev/video*
```

### File Permission Issues
**Cannot edit config files locally:**
```bash
# Files should have rw permissions (644)
ls -la mainsail/config.json
ls -la mainsail/nginx/default.conf

# If not, restart containers to fix permissions
docker compose restart mainsail
```

### Hardware Acceleration Issues
**GPU streaming not working (if you have NVIDIA GPU):**
```bash
# Verify GPU is available
ls /dev/dri

# Check NVIDIA runtime is installed
docker run --runtime=nvidia --rm nvidia/cuda nvidia-smi

# View go2rtc GPU logs
docker logs qidi_go2rtc | grep -i nvenc
```

## 🌐 Network Setup

**Default Network Configuration:**
- Printer IP: `192.168.68.35` (QIDI Plus 4)
- Host IP: `192.168.68.26` (Docker host)

**If your network is different:**
1. Find your printer's IP: Check your printer's LCD screen or router DHCP table
2. Find your host's IP: Run `ip addr` or `hostname -I`
3. Update `.env` with correct values:
   ```bash
   PRINTER_IP=your.printer.ip
   HOST_IP=your.host.ip
   ```
4. Restart services: `docker compose restart`

## 📊 Performance Optimization

- **Memory Usage:** Camera streams are memory-intensive per connected client
- **Bandwidth:** Use MJPEG for better efficiency than H.264 transcoding
- **CPU:** H.264 encoding with GPU is much faster than CPU encoding
- **Network:** 25fps framerate balances quality and bandwidth

## ⚠️ Security Recommendations

1. **Environment Variables**
   - Store `.env` with safe permissions: `chmod 600 .env`
   - Never commit `.env` to git (already in `.gitignore`)

2. **Network Access**
   - Don't expose ports to untrusted networks
   - Use firewall rules to restrict access
   - Consider VPN for remote access

3. **Keep Updated**
   ```bash
   docker compose pull
   docker compose up -d
   ```

## 📚 Documentation & Support

- **Mainsail:** https://docs.mainsail.xyz/
- **Moonraker API:** https://moonraker.readthedocs.io/
- **go2rtc:** https://github.com/AlexxIT/go2rtc
- **Obico:** https://www.obico.io/

## 📝 License

MIT License - Copyright (c) 2026 Christos Ploutarchou

This project is provided as-is for personal use with QIDI Plus 4 printers. See [LICENSE](LICENSE) file for full license details.

---

**Last Updated:** February 2026  
**Printer:** QIDI Plus 4  
**Stack Version:** 1.0
