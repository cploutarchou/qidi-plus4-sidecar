# QIDI Plus 4 Sidecar - Windows Setup Guide (Production Ready)

Welcome! This guide walks you through setting up your QIDI Plus 4 sidecar on Windows in a way that's reliable, secure, and ready for real-world use. Don't worry if some parts look technical—I'll break everything down into manageable steps.

## Table of Contents

1. Camera Setup (USB Device Pass-through or Stream)
2. Docker & Prerequisites Configuration
3. Initial Setup & Configuration
4. Security & Network Hardening
5. Health Monitoring & Logging
6. Persistent Data & Backups
7. Operational Procedures
8. Troubleshooting & Recovery

---

## 1. Camera Setup — Make the Camera Available to the Stack

So your printer needs to see that USB camera you've got connected. Since this software was built for Linux but we're running it on Windows, we need a special bridge to make it work. Good news: you have a few straightforward options to choose from.

### Option 1 — usbipd-win (attach USB camera to WSL2) - RECOMMENDED

This is the cleanest approach. You're essentially "passing" your USB camera through to the Linux container, which is what it expects. Think of it like giving the container direct access to the hardware.

**What you'll need:**

- Windows 10/11 Pro or Enterprise
- WSL2 (Windows Subsystem for Linux 2) installed
- A WSL distro like Ubuntu
- Docker Desktop running with WSL2 integration
- usbipd-win tool installed

**Here's how to set it up:**

1. Open PowerShell as Administrator and list your USB devices:

```powershell
usbipd.exe wsl list
```

 Find your camera in the list and note its BUSID (something like `1-1`).

1. Attach it to WSL:

```powershell
usbipd.exe wsl attach --busid <BUSID>
```

1. Verify it shows up inside WSL/Linux:

```bash
ls -la /dev/video*
```

You should see `/dev/video0` or similar. Great! Now start your stack:

```bash
docker compose up -d
```

**Things to remember:**

- Docker needs WSL2 backend enabled (go to Docker Desktop → Settings → Resources → WSL Integration)
- When you're done, detach the camera with: `usbipd.exe wsl detach --busid <BUSID>`
- This approach gives you the best performance and fastest camera access

### Option 2 — Run a Windows streamer (easier, but slightly less performant)

If you'd rather not mess with usbipd-win, you can just run ffmpeg on Windows to stream your camera to the container. It's like having an intermediary that talks to both.

```powershell
ffmpeg -f dshow -i video="<Your Camera Name>" -c:v libx264 -preset veryfast -f rtsp rtsp://<your-host-ip>:8554/qidi_plus4
```

Replace `<your-host-ip>` with your Windows machine's IP address. This works, but you'll have an extra software layer translating everything, so performance is slightly lower than Option 1.

### Option 3 — Skip Docker entirely and run on Windows (Advanced)

If Docker feels like overkill to you, you can run go2rtc natively on Windows. Just download the Windows binary and configure it to use DirectShow instead of Linux's Video4Linux.

```powershell
ffmpeg -f dshow -i video="Your Camera Name"
```

You'll need to update your `go2rtc.yaml` file, but if you're comfortable configuring services natively, this is perfectly fine.

---

## 2. Make Sure Your System is Ready

Before we dive in, let's make sure your Windows machine has what it needs. Think of this like checking the box before you assemble furniture—it saves headaches later.

### What you need on your machine

- **Windows 10/11 Pro or Enterprise** (Home edition doesn't support Docker, unfortunately)
- **WSL 2** set up and working (Docker Desktop needs this)
- **8 GB RAM minimum** (realistically, 16 GB is nicer so Docker doesn't choke your other programs)
- **SSD with 20 GB free** (for the container images and Docker's disk usage)
- **GPU** (optional, but if you have NVIDIA, it'll speed up video encoding significantly)

### Set up Docker Desktop the right way

Docker can be a resource hog if you let it. Let's give it enough to work comfortably without starving your Windows machine.

1. **Tell Docker to be a good citizen** (limit resources):
   - Open Docker Desktop
   - Go to Settings → Resources
   - Set Memory limit to 6 GB (this leaves 2 GB for Windows itself)
   - Set CPUs to 4 (leave the rest for your OS)
   - Disk image size: 30 GB (enough room to grow)

2. **Enable WSL 2 Integration** (this is what lets Docker talk to Linux):
   - Settings → Resources → WSL Integration
   - Check the box for your WSL distro (usually Ubuntu)

3. **Restart Docker Desktop** to apply the changes

### Get your network sorted

Your printer and your Docker host need to find each other reliably. Moving IPs around is a recipe for things breaking randomly. Here's how to prevent that:

1. **Give your Windows machine a static IP**:
   - Open Command Prompt and run: `ipconfig /all` to see what IP you currently have
   - Log into your router's settings and assign a static IP to that Windows machine
   - Alternatively, set a static IP in Windows Settings → Network & Internet → Advanced network settings

2. **Write down both IPs** (you'll need these for configuration):
   - **PRINTER_IP**: What IP address is your QIDI Plus 4 printer on? (Check your printer's web interface)
   - **HOST_IP**: Your Windows Docker host's static IP (e.g., 192.168.1.100)
   - Make sure both are on the same subnet (e.g., both 192.168.x.x)

---

## 3. Let's Set This Thing Up

Now the fun part. Don't worry—it's mostly copy-paste.

### Step 1: Navigate to your project folder

```powershell
# Go to where you cloned the project
cd C:\path\to\qidi-plus4-sidecar

# Check that all the .example files are there (they should be)
Get-ChildItem -Recurse -Include "*.example" | Select-Object FullName
```

### Step 2: Create your environment file

This file will hold all your personal settings (IPs, tokens, etc.).

```powershell
# Copy the template
Copy-Item ".env.example" ".env"
```

Now open `.env` in Notepad or VS Code and fill in YOUR values:

```powershell
PRINTER_IP=192.168.1.100        # Your QIDI Plus 4's actual IP (from earlier)
HOST_IP=192.168.1.50            # Your Windows machine's static IP
TZ=Europe/London                 # Your actual timezone (or US/Eastern, Asia/Tokyo, etc.)
OBICO_AUTH_TOKEN=your-token-here # Optional: only if you want AI print failure detection
OBICO_SECRET_KEY=some-random-key # Optional: generate with: [guid]::NewGuid().ToString()
```

**Super important**: This file contains your secrets. Never, ever commit it to Git or share it. Keep `.env.example` in your repo so others know what variables are needed, but keep `.env` for yourself only.

### Step 3: Copy the configuration templates

Each service needs a config file. Good news: there are templates for everything.

```powershell
# Copy all the example config files
Copy-Item "go2rtc\go2rtc.yaml.example" "go2rtc\go2rtc.yaml"
Copy-Item "mainsail\config.json.example" "mainsail\config.json"
Copy-Item "mainsail\nginx\default.conf.example" "mainsail\nginx\default.conf"
Copy-Item "obico\moonraker-obico.cfg.example" "obico\moonraker-obico.cfg"
```

Most of these will work as-is. The Docker startup scripts are smart enough to fill in the placeholder values (like `${PRINTER_IP}`) with what you set in `.env`.

### Step 4: Do a sanity check

Let's make sure you didn't miss anything:

```powershell
# Check that all the important files are where they should be
$requiredFiles = @(
    ".env",
    "go2rtc\go2rtc.yaml",
    "mainsail\config.json",
    "mainsail\nginx\default.conf",
    "obico\moonraker-obico.cfg"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $file missing" -ForegroundColor Red
    }
}
```

You want to see all green checkmarks. If something's red, go back and copy that file.

---

## 4. Secure Your Setup

Now that it's working, let's make sure only the people (and devices) you trust can access it. Think of this like installing a deadbolt on your door—essential if you care about security.

### A. Configure Windows Firewall

**Why?** By default, anyone on the internet could potentially reach your services. We're going to say "only devices on my home network are allowed."

Paste this into PowerShell as Administrator:

```powershell
# Allow your local network (192.168.x.x) to access each service
New-NetFirewallRule -DisplayName "QIDI Mainsail (Local)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080 -RemoteAddress 192.168.0.0/16
New-NetFirewallRule -DisplayName "QIDI WebRTC (Local)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8555 -RemoteAddress 192.168.0.0/16
New-NetFirewallRule -DisplayName "QIDI RTSP (Local)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8554 -RemoteAddress 192.168.0.0/16
New-NetFirewallRule -DisplayName "QIDI Metrics (Local)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9101 -RemoteAddress 192.168.0.0/16

# And block the entire Internet from accessing them
New-NetFirewallRule -DisplayName "Block External Access" -Direction Inbound -Action Block -Protocol TCP -LocalPort 8080,8554,8555,1984,9101 -RemoteAddress "!192.168.0.0/16"
```

Now the rest of the world can't peek in, but you and your home network can still use everything.

### B. If you need remote access (through VPN)

Maybe you want to check on your printer while you're away. That's cool, but do it securely via VPN, not the open internet. If you go that route, add authentication:

1. Edit `mainsail/nginx/default.conf` and add:
   - HTTP Basic Auth (username + password protection)
   - Rate limiting (blocks attackers trying to spam requests)
   - SSL/TLS encryption (scrambles traffic so nobody can snoop)

2. **Create credentials**:

Go to <https://httpd.apache.org/docs/current/misc/password_digests.html>, generate a bcrypt hash, and add it to your Nginx config.

**Pro tip**: Only do this if you're accessing through a VPN. Opening things to the internet without VPN is asking for trouble.

### C. Volume Security

Ensure configuration files are read-only in containers:

```yaml
# Verify in docker-compose.yml:
volumes:
  - ./go2rtc/go2rtc.yaml:/config/go2rtc.yaml:ro       # ro = read-only
  - ./mainsail/nginx/default.conf:/etc/nginx/conf.d/default.conf.template:ro
```

### D. Network Isolation (Optional)

For production, create an isolated Docker network:

```powershell
docker network create qidi_isolated --subnet=172.20.0.0/16
# Then update docker-compose.yml networks section
```

---

## 5. Keep an Eye on Things

Once it's running, you want to know if something goes wrong. Let's set up monitoring and logging.

### A. Health Checks (so you know if something's broken)

Add this to your docker-compose.yml so Docker automatically checks if services are still breathing:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/"] 
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### B. Reading the logs (debugging when things break)

When something goes wrong, the logs tell you what happened. Here's how to read them:

```powershell
# Watch all services in real-time (like tail -f on Linux)
docker compose logs -f

# Watch just one service (much quieter)
docker compose logs -f mainsail    # or go2rtc, or moonraker-exporter

# See the last 100 lines (good for a quick overview)
docker compose logs --tail=100 -t

# Save logs to a file for later analysis
docker compose logs --tail=1000 > qidi-logs-$(Get-Date -Format 'yyyyMMdd').log
```

When troubleshooting, start with the logs. They're your friend.

### C. Prevent logs from eating your hard drive

Logs can fill up over time. Let's make sure old logs get deleted automatically so your disk doesn't become a log storage facility.

Edit `C:\ProgramData\Docker\config\daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "10"
  }
}
```

Then restart Docker Desktop. Now logs won't exceed 50MB per file, and you'll keep at most 10 files. Old ones get deleted automatically.

### D. Monitor Container Health

```powershell
# Check container status
docker compose ps

# Detailed health status
docker inspect qidi_go2rtc --format='{{.State.Health}}'

# Export metrics to local monitoring
curl http://localhost:9101/metrics > metrics.txt

# Watch stats in real-time
docker stats
```

---

## 6. Don't Lose Your Stuff

Imagine you've got everything configured perfectly, then your computer crashes. Wouldn't it suck to lose it all? Let's prevent that.

### A. Make your data actually stick around

Containers are like temporary workspaces. By default, when you restart them, any data inside gets thrown away. That's actually a feature for most things, but we want to keep our configuration.

Add this to your docker-compose.yml:

```yaml
volumes:
  qidi_mainsail_data:
    driver: local
  qidi_moonraker_data:
    driver: local

services:
  mainsail:
    volumes:
      - qidi_mainsail_data:/data  # Add this line
```

### B. Back up your configs regularly

Even if Docker keeps things persistent, you should have backups outside of Docker. Think of it like insurance.

Create a backup script called `backup-qidi.ps1`:

```powershell
# Create backup script
$backup_dir = "$env:USERPROFILE\Documents\qidi-backups"
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backup_name = "qidi-backup-$timestamp.zip"

# Create backup directory if missing
New-Item -ItemType Directory -Force -Path $backup_dir | Out-Null

# Backup all configuration files
Compress-Archive -Path `
    ".env",
    "go2rtc/go2rtc.yaml",
    "mainsail/config.json",
    "mainsail/nginx/default.conf",
    "obico/moonraker-obico.cfg" `
    -DestinationPath "$backup_dir\$backup_name" -Force

Write-Host "✓ Backup created: $backup_dir\$backup_name"

# Delete backups older than 30 days
Get-ChildItem "$backup_dir\qidi-backup-*.zip" | `
    Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | `
    Remove-Item

Write-Host "✓ Old backups cleaned"
```

**Now automate it** so backups happen whether you remember or not:

1. Open Windows Task Scheduler
2. Create a new task with these settings:
   - **Trigger**: Weekly on Sunday at 2 AM (when you're sleeping)
   - **Action**: Run `powershell.exe -File "C:\path\to\backup-qidi.ps1"`

Now you'll have fresh backups sitting in your Documents folder, going back 30 days.

### C. Disaster recovery (when (not if) you need to restore)

God forbid your config gets corrupted or you accidentally delete something important. Here's how to get back to a previous state:

```powershell
# 1. Stop everything
docker compose down

# 2. Extract the backup (replace with your actual backup date)
Expand-Archive -Path "$backup_dir\qidi-backup-YYYY-MM-DD_HHMMSS.zip" -DestinationPath . -Force

# 3. Verify you got the right files back
dir .env, go2rtc\go2rtc.yaml, mainsail\config.json

# 4. Restart
docker compose up -d
```

Done. You're back in business.

---

## 7. Day-to-Day Operations

Now that everything's set up, here's how to run it safely.

### A. Starting it up (the right way)

Don't just slam `docker compose up`. Do it thoughtfully:

```powershell
# 1. Check that your configuration is valid (catches typos before they cause problems)
docker compose config > $null
if ($?) { Write-Host "✓ Configuration valid" } else { exit 1 }

# 2. See if Docker has enough resources left
docker system df

# 3. Start everything
docker compose up -d

# 4. Give services time to boot (2-3 minutes is normal)
Start-Sleep -Seconds 5

# 5. Check that everything's running
docker compose ps

# 6. Do a quick sanity check (ping each service)
curl -s http://localhost:8080 > $null && Write-Host "✓ Mainsail is up"
curl -s http://localhost:1984/api/streams > $null && Write-Host "✓ go2rtc is up"
curl -s http://localhost:9101/metrics > $null && Write-Host "✓ Metrics are up"
```

### B. Shutting down properly

Kind of the opposite of startup:

```powershell
# Normal shutdown (safe, preserves data)
docker compose down

# Wait for everything to stop
Start-Sleep -Seconds 3

# Verify it stopped
docker compose ps

# ONLY use this if you want to nuke everything:
# docker compose down -v    (WARNING: deletes all container data!)
```

### C. Updating to newer versions

Every month or so, new versions of the services come out with bug fixes and security patches. Here's the safe way to upgrade:

```powershell
# 1. Grab the latest images
docker compose pull

# 2. See what's going to change
docker compose config

# 3. Restart services (one at a time, so nothing goes down)
docker compose up -d

# 4. Make sure everything started
docker compose ps

# 5. Watch the logs for the first few minutes for any errors
docker compose logs --tail=50
```

### D. Monitor System Resources

```powershell
# Real-time container resource usage
docker stats

# Disk usage by Docker
docker system df

# Network diagnostics to printer
Test-NetConnection -ComputerName $env:PRINTER_IP -Port 7125 -Verbose

# Detailed container inspection
docker inspect qidi_go2rtc | Select-String -Pattern "Status|Error"
```

### E. Database & Cache Cleanup (Monthly)

```powershell
# Remove unused images (frees disk space)
docker image prune -a --force

# Remove unused networks
docker network prune --force

# Remove unused volumes (preserves data!)
docker volume prune --force

# Full rebuild from scratch (if needed - starts fresh)
docker compose down
docker image rm qidi/go2rtc-nvenc:latest
docker compose up -d --build
```

---

## 8. When Things Go Wrong (Troubleshooting)

Don't panic. Usually it's something simple.

### A. "Help, nothing's starting!"

Try these steps in order:

```powershell
# 1. Check if your config has any syntax errors
docker compose config

# 2. Read the error messages (they're usually helpful)
docker compose logs --tail=100

# 3. Make sure your .env file doesn't have typos
Get-Content .env | Select-String -Pattern "^[A-Z_]+=.*$"

# 4. Check if Docker itself is working
docker ps -a
docker events --tail=50
```

### B. "Where's my camera?"

The streaming service can't find your USB camera. Here's how to fix it:

**Scenario 1: You used Option 1 (usbipd-win) but forgot to attach it**

```powershell
# List your USB devices and find the camera
usbipd wsl list

# Attach it (replace 1-1 with the actual BUSID)
usbipd wsl attach --busid 1-1

# Verify it showed up in Linux
bash -c "ls -la /dev/video*"

# Restart go2rtc
docker compose restart go2rtc
```

**Scenario 2: Device attached but go2rtc still can't see it**

```bash
# Inside WSL, check if the device is really there
ls -la /dev/video*

# If nothing shows up, try re-attaching
usbipd wsl detach --busid 1-1
usbipd wsl attach --busid 1-1

# Restart go2rtc and check its logs
docker compose restart go2rtc
docker compose logs go2rtc | grep -i video
```

**Scenario 3: Device is there but permissions are wrong**

```bash
# Inside WSL, fix permissions
sudo chmod 666 /dev/video0
docker compose restart go2rtc
```

### C. Network & Connectivity Issues

```powershell
# 1. Verify IPs match docker-compose environment
Get-Content .env | Select-String "PRINTER_IP|HOST_IP"

# 2. Test printer connectivity
Test-NetConnection -ComputerName 192.168.x.x -Port 7125 -Verbose

# 3. Check DNS resolution
Resolve-DnsName printer.local

# 4. Restart Docker network
docker compose down
docker network prune --force
docker compose up -d

# 5. Check firewall rules
Get-NetFirewallRule -DisplayName "*QIDI*" | Get-NetFirewallPortFilter
```

### D. Memory Leaks or High CPU Usage

```powershell
# 1. Monitor resource consumption
docker stats --no-stream

# 2. Identify the problematic container
docker top qidi_go2rtc

# 3. Restart that service to free memory
docker compose restart go2rtc

# 4. If persistent, rebuild container
docker compose down
docker image rm qidi/go2rtc-nvenc:latest
docker compose up -d --build

# 5. Check for memory leaks in logs
docker compose logs qidi_go2rtc | Select-String -Pattern "memory|leak|OOM"
```

### E. GPU Not Accelerating (NVIDIA)

```powershell
# 1. Verify NVIDIA Docker support
docker run --rm --gpus all nvidia/cuda:11.0-runtime nvidia-smi

# 2. Check docker-compose configuration
docker compose ps | Select-String "qidi_go2rtc"

# 3. Verify GPU is detected in container
docker exec qidi_go2rtc nvidia-smi

# 4. Check go2rtc is using GPU codec
docker compose logs go2rtc | Select-String -Pattern "nvenc|gpu|264"

# 5. Rebuild with NVIDIA support
docker compose down
docker compose up -d --build
```

### F. Disk Space Full (Container Won't Start)

```powershell
# Check disk space
dir C:\ ; Get-Volume C

# Check Docker disk usage
docker system df

# Clean up unused images, containers, volumes
docker system prune -a --volumes

# If still full, expand Docker disk image:
# Stop Docker Desktop → Settings → Resources → Disk Image file → Expand
```

### G. Recovery from Failed State

```powershell
# Level 1: Restart services (safest)
docker compose restart

# Level 2: Full stop and start (safer)
docker compose down
docker compose up -d

# Level 3: Clean containers but keep volumes (moderate risk)
docker compose down
docker image prune -a
docker compose up -d

# Level 4: Full system reset (loses all container data!)
docker compose down -v
docker system prune -a --force

# Restore from backup
Expand-Archive -Path "backup-qidi-YYYY-MM-DD_HHMMSS.zip" -DestinationPath . -Force

# Restart fresh
docker compose up -d
```

---

## Checklist: Keep Your Setup Healthy

Here's what you should do to keep this running smoothly:

1. **Weekly**: Glance at the logs. Five minutes. Just make sure there are no ERROR lines screaming at you.
2. **Weekly**: Run the backup script (or set it to auto-run). You want multiple backup points.
3. **Monthly**: Do `docker compose pull && docker compose up -d` to get security patches.
4. **Quarterly**: Pick one backup at random and actually restore it. Make sure it works. You don't want to find out your backups are broken when you need them.
5. **Quarterly**: Document anything weird you had to fix. Future you will thank current you.
6. **Whenever**: If you change something in a config file, make a quick note of what and why.

**For peace of mind:**

- Keep your Docker host on a static IP (so your printer can always find it)
- Only allow your local network through the firewall
- Rotate logs so they don't fill your disk
- Consider setting up Task Scheduler alerts if something breaks
- If you ever open these services to the internet, use a VPN and add authentication

---

## Performance Tuning

### For high-bandwidth streaming

- Enable hardware acceleration (NVIDIA NVENC)
- Set bitrate limits in go2rtc.yaml
- Use lower resolution if needed (1280x720 vs 1920x1080)

### For low-latency camera feeds

- Reduce go2rtc buffering
- Increase WebRTC bitrate
- Use h264 codec instead of vp8

### For resource-constrained systems

- Limit Docker memory allocation
- Disable Obico if not needed
- Use MJPEG instead of WebRTC

---

## Additional Resources

- Docker Documentation: <https://docs.docker.com/>
- Docker Compose: <https://docs.docker.com/compose/>
- WSL 2 Setup: <https://docs.microsoft.com/en-us/windows/wsl/>
- QIDI Plus 4 Moonraker: <https://moonraker.readthedocs.io/>
- Mainsail UI: <https://docs.mainsail.xyz/>
- go2rtc Project: <https://github.com/AlexxIT/go2rtc>
- Obico AI Detection: <https://www.obico.io/>
