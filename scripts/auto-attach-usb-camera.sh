#!/usr/bin/env bash
set -euo pipefail

# Auto-attach USB camera to WSL2 using usbipd
# Runs before docker-compose up to ensure camera is available

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

detect_platform() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo unknown)"

  if [[ "${uname_s}" == "Linux" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      echo "wsl"
      return
    fi
  fi

  echo "other"
}

read_env_value() {
  local key="$1"
  if [[ -f "${ENV_FILE}" ]]; then
    awk -F= -v k="${key}" '$1==k {print substr($0, index($0,"=")+1); exit}' "${ENV_FILE}"
  fi
}

is_camera_attached() {
  # Check if /dev/video0 or similar exists and is readable
  if ls /dev/video* >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

attach_usb_camera_wsl() {
  local busid camera_name
  busid="$(read_env_value "USB_CAMERA_BUSID")"

  if [[ -z "${busid}" ]]; then
    echo -e "${YELLOW}[usb-camera] USB_CAMERA_BUSID not configured in .env, skipping WSL2 attach.${NC}"
    return 1
  fi

  camera_name="$(read_env_value "USB_CAMERA_NAME")"
  camera_name="${camera_name:-USB Camera}"

  # Check if already attached on WSL side
  if is_camera_attached; then
    echo -e "${GREEN}[usb-camera] Camera already attached (/dev/video* detected).${NC}"
    return 0
  fi

  # Try to attach via usbipd
  if command -v usbipd.exe >/dev/null 2>&1; then
    echo -e "${BLUE}[usb-camera] Attaching ${camera_name} (BUSID: ${busid}) to WSL2...${NC}"
    
    if usbipd.exe attach --wsl --busid "${busid}" 2>&1 | tee /tmp/usbipd-attach.log; then
      sleep 2  # Wait for device to appear
      
      if is_camera_attached; then
        echo -e "${GREEN}[usb-camera] Successfully attached ${camera_name} to WSL2!${NC}"
        ls -la /dev/video* 2>/dev/null | head -3
        return 0
      else
        echo -e "${YELLOW}[usb-camera] Attach command succeeded but camera not yet visible; continuing...${NC}"
        return 0
      fi
    else
      local exit_code=$?
      if grep -q "already attached" /tmp/usbipd-attach.log 2>/dev/null; then
        echo -e "${GREEN}[usb-camera] Camera already attached.${NC}"
        sleep 1
        return 0
      else
        echo -e "${YELLOW}[usb-camera] Could not attach camera (exit code: ${exit_code}). Continuing with fallback.${NC}"
        return 1
      fi
    fi
  else
    echo -e "${YELLOW}[usb-camera] usbipd not found on Windows PATH. Please run in PowerShell (Admin).${NC}"
    return 1
  fi
}

main() {
  local platform

  platform="$(detect_platform)"

  if [[ "${platform}" != "wsl" ]]; then
    echo -e "${BLUE}[usb-camera] Not running on WSL2; skipping USB camera attach.${NC}"
    return 0
  fi

  echo -e "${BLUE}[usb-camera] WSL2 detected. Attempting USB camera auto-attach...${NC}"

  if ! attach_usb_camera_wsl; then
    echo -e "${YELLOW}[usb-camera] USB camera attachment failed or unavailable.${NC}"
    echo -e "${YELLOW}[usb-camera] Make sure usbipd-win is installed and camera is configured in .env.${NC}"
    echo -e "${YELLOW}[usb-camera] System will continue with fallback camera mode.${NC}"
  fi
}

main "$@"
