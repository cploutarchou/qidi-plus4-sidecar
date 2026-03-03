#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Starting go2rtc with hardware acceleration"
echo "=================================================="

# Check for video devices
VIDEO_DEVICE_FOUND=false
if [ -e "/dev/video0" ]; then
    echo -e "${GREEN}✓ Video device /dev/video0 found${NC}"
    VIDEO_DEVICE_FOUND=true
    ls -la /dev/video* 2>/dev/null || true
else
    echo -e "${RED}✗ ERROR: Video device /dev/video0 not found${NC}"
    echo -e "${YELLOW}⚠ Camera streaming will not be available${NC}"
    echo ""
    echo "To fix this:"
    echo "  1. Connect a USB camera to your system"
    echo "  2. Verify with: ls -la /dev/video*"
    echo "  3. Update docker-compose.yml devices section if using different device"
    echo "  4. Run: docker compose --profile camera up -d"
    echo ""
fi

# Check for DRI (GPU) devices
if [ -d "/dev/dri" ]; then
    echo -e "${GREEN}✓ GPU devices available for hardware acceleration${NC}"
    ls -la /dev/dri/ 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Warning: No GPU devices found at /dev/dri${NC}"
    echo -e "${YELLOW}  Hardware acceleration may not work${NC}"
fi

# On Linux ARM boards, hardware encoding support depends on kernel/ffmpeg setup.
# If /dev/dri is available, hardware acceleration may be used by ffmpeg codecs.

# Verify config file
if [ -f "/config/go2rtc.yaml" ]; then
    echo -e "${GREEN}✓ Configuration file found${NC}"
else
    echo -e "${RED}✗ ERROR: Configuration file /config/go2rtc.yaml not found${NC}"
    echo "Please ensure go2rtc.yaml is mounted correctly"
    exit 1
fi

echo "=================================================="

# If no video device found, log error but continue (for systems without camera)
if [ "$VIDEO_DEVICE_FOUND" = false ]; then
    echo -e "${RED}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║  ERROR: No video device detected              ║"
    echo "║  go2rtc will start but streaming won't work   ║"
    echo "║  See logs above for troubleshooting steps     ║"
    echo "╔════════════════════════════════════════════════╗"
    echo -e "${NC}"
    
    # Write error to a file for healthcheck
    echo "NO_VIDEO_DEVICE" > /tmp/go2rtc_error.log
fi

# Start go2rtc
echo "Starting go2rtc..."
exec "$@"
