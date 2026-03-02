#!/bin/bash
# Setup script for QIDI Plus 4 Sidecar
# Run this to fix any permission issues and set up config files

set -e

echo "Setting up QIDI Plus 4 Sidecar..."

# Fix mainsail config.json if it's a directory (created by Docker)
if [ -d "mainsail/config.json" ]; then
    echo "Fixing mainsail/config.json (removing directory created by Docker)..."
    sudo rm -rf mainsail/config.json
fi

# Create config.json if it doesn't exist
if [ ! -f "mainsail/config.json" ]; then
    if [ -f "mainsail/config.json.example" ]; then
        echo "Creating mainsail/config.json from example..."
        cp mainsail/config.json.example mainsail/config.json
    else
        echo "Warning: mainsail/config.json.example not found"
    fi
fi

# Fix nginx default.conf if it's a directory (created by Docker)
if [ -d "mainsail/nginx/default.conf" ]; then
    echo "Fixing mainsail/nginx/default.conf (removing directory created by Docker)..."
    sudo rm -rf mainsail/nginx/default.conf
fi

# Create default.conf if it doesn't exist
if [ ! -f "mainsail/nginx/default.conf" ]; then
    if [ -f "mainsail/nginx/default.conf.example" ]; then
        echo "Creating mainsail/nginx/default.conf from example..."
        cp mainsail/nginx/default.conf.example mainsail/nginx/default.conf
    else
        echo "Warning: mainsail/nginx/default.conf.example not found"
    fi
fi

# Make entrypoint script executable
if [ -f "go2rtc/entrypoint.sh" ]; then
    chmod +x go2rtc/entrypoint.sh
    echo "Made go2rtc/entrypoint.sh executable"
fi

# Check for video devices
echo ""
echo "Checking for video devices..."
if ls /dev/video* 2>/dev/null; then
    echo "✓ Video devices found"
    echo ""
    echo "To start with camera support:"
    echo "  docker compose --profile camera up -d"
else
    echo "✗ No video devices found"
    echo ""
    echo "To start without camera (recommended for your system):"
    echo "  docker compose up -d"
    echo ""
    echo "  go2rtc will log an error but other services will work"
fi

echo ""
echo "Setup complete!"
