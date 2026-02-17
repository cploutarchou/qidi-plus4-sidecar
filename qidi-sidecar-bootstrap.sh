#!/bin/bash
set -euo pipefail

# QIDI Plus 4 Sidecar - Docker Compose Bootstrap
# Sets up containerized services for 3D printer management and monitoring

echo "🚀 QIDI Plus 4 Sidecar - Starting Bootstrap..."

# 1. System Update
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y




# 4. Install v4l-utils (camera tools)
echo "📹 Installing camera utilities..."
sudo apt install -y v4l-utils ffmpeg

# 5. Create project directory
echo "📁 Creating project structure..."
mkdir -p ~/qidi-sidecar/{obico,go2rtc,prometheus-exporter,data}
cd ~/qidi-sidecar

# 6. Create docker-compose.yml
echo "📝 Creating docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  # go2rtc - WebRTC streaming with hardware acceleration
  go2rtc:
    image: alexxit/go2rtc:latest
    container_name: qidi_go2rtc
    restart: unless-stopped
    network_mode: host
    devices:
      - /dev/video0:/dev/video0  # IMX291 camera
      - /dev/dri:/dev/dri        # AMD Radeon hardware acceleration
    volumes:
      - ./go2rtc/go2rtc.yaml:/config/go2rtc.yaml:ro
    environment:
      - TZ=Europe/Nicosia
    privileged: true

  # Obico Server (self-hosted)
  obico-server:
    image: thespaghettidetective/web:latest
    container_name: qidi_obico_server
    restart: unless-stopped
    ports:
      - "3334:3334"
    volumes:
      - ./obico/data:/app/data
    environment:
      - TZ=Europe/Nicosia
      - DJANGO_SECRET_KEY=${OBICO_SECRET_KEY:-change_me_to_random_string}
      - REDIS_URL=redis://obico-redis:6379
    depends_on:
      - obico-redis

  # Obico ML Worker (AI detection)
  obico-ml:
    image: thespaghettidetective/ml_api:latest
    container_name: qidi_obico_ml
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri  # Use AMD GPU for inference if supported
    environment:
      - TZ=Europe/Nicosia
      - ML_API_HOST=0.0.0.0
      - ML_API_PORT=3333
    depends_on:
      - obico-server

  # Redis for Obico
  obico-redis:
    image: redis:7-alpine
    container_name: qidi_obico_redis
    restart: unless-stopped
    volumes:
      - ./obico/redis:/data

  # Moonraker Prometheus Exporter
  moonraker-exporter:
    image: ghcr.io/scross01/prometheus-klipper-exporter:latest
    container_name: qidi_moonraker_exporter
    restart: unless-stopped
    ports:
      - "9101:9101"
    environment:
      - KLIPPER_EXPORTER_MOONRAKER_HOST=192.168.68.35
      - KLIPPER_EXPORTER_MOONRAKER_PORT=7125
      - TZ=Europe/Nicosia

networks:
  default:
    name: qidi_network
EOF

# 7. Create go2rtc config
echo "📝 Creating go2rtc.yaml..."
mkdir -p go2rtc
cat > go2rtc/go2rtc.yaml <<'EOF'
streams:
  qidi_plus4:
    # IMX291 camera - 1080p MJPEG → H.264 hardware encode
    - ffmpeg:device?video=/dev/video0&input_format=mjpeg&video_size=1920x1080&framerate=30#video=h264#hardware

webrtc:
  listen: ":8555"

api:
  listen: ":1984"

rtsp:
  listen: ":8554"
EOF

# 8. Create .env file
echo "📝 Creating .env file..."
cat > .env <<EOF
OBICO_SECRET_KEY=$(openssl rand -hex 32)
TZ=Europe/Nicosia
EOF

# 9. Set permissions
echo "🔒 Setting permissions..."
sudo chown -R $USER:$USER ~/qidi-sidecar

# 10. Enable hardware acceleration check
echo "🎮 Checking AMD GPU availability..."
ls -la /dev/dri/ || echo "⚠️  No /dev/dri found - hardware acceleration may not work"

# 11. Test camera
echo "📹 Testing IMX291 camera..."
v4l2-ctl --list-devices || echo "⚠️  Camera not detected yet - plug in IMX291"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📋 Next steps:"
echo "1. Plug in your IMX291 USB camera"
echo "2. Verify camera: v4l2-ctl --list-formats-ext -d /dev/video0"
echo "3. Start services: cd ~/qidi-sidecar && docker compose up -d"
echo "4. Access go2rtc: http://$(hostname -I | awk '{print $1}'):1984"
echo "5. Access Obico: http://$(hostname -I | awk '{print $1}'):3334"
echo "6. Prometheus exporter: http://$(hostname -I | awk '{print $1}'):9101/metrics"
echo ""
echo "🔄 To view logs: docker compose logs -f"
echo "🛑 To stop: docker compose down"
echo ""