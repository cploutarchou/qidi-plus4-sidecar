#!/usr/bin/env bash
set -euo pipefail

# Auto-detect camera device and persist CAMERA_DEVICE to .env
# Works on Linux, Raspberry Pi, WSL2, and macOS (fallback mode)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
GO2RTC_CONFIG_FILE="${ROOT_DIR}/go2rtc/go2rtc.yaml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

detect_platform() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo unknown)"

  if [[ "${uname_s}" == "Darwin" ]]; then
    echo "macos"
    return
  fi

  if [[ "${uname_s}" == "Linux" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      echo "wsl"
    else
      echo "linux"
    fi
    return
  fi

  echo "other"
}

detect_linux_video_device() {
  if [[ -e /dev/video0 ]]; then
    echo "/dev/video0"
    return
  fi

  local first_video
  first_video="$(ls -1 /dev/video* 2>/dev/null | head -n1 || true)"
  if [[ -n "${first_video}" ]]; then
    echo "${first_video}"
    return
  fi

  echo ""
}

upsert_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"

  touch "${file}"

  local tmp
  tmp="$(mktemp)"

  awk -v k="${key}" -v v="${value}" '
    BEGIN { updated=0 }
    $0 ~ "^"k"=" {
      print k"="v
      updated=1
      next
    }
    { print }
    END {
      if (!updated) print k"="v
    }
  ' "${file}" > "${tmp}"

  mv "${tmp}" "${file}"
}

read_env_value() {
  local key="$1"
  if [[ -f "${ENV_FILE}" ]]; then
    awk -F= -v k="${key}" '$1==k {print substr($0, index($0,"=")+1); exit}' "${ENV_FILE}"
  fi
}

is_loopback_camera_url() {
  local url="$1"
  local host_ip

  host_ip="$(read_env_value "HOST_IP")"

  if [[ "${url}" == /camera/* ]]; then
    return 0
  fi

  if [[ -n "${host_ip}" && "${url}" =~ ^https?://${host_ip}(:[0-9]+)?/camera/ ]]; then
    return 0
  fi

  return 1
}

detect_external_stream_url() {
  local configured_url
  configured_url="$(read_env_value "EXTERNAL_WEBCAM_URL")"

  if [[ -z "${configured_url}" ]]; then
    echo ""
    return
  fi

  # Ignore template placeholder values.
  if [[ "${configured_url}" == CHANGE_ME* || "${configured_url}" == "<CHANGE_ME>" ]]; then
    echo -e "${YELLOW}[camera] EXTERNAL_WEBCAM_URL is still a placeholder; ignoring.${NC}" >&2
    echo ""
    return
  fi

  if [[ ! "${configured_url}" =~ ^https?:// && ! "${configured_url}" =~ ^rtsp:// ]]; then
    echo -e "${YELLOW}[camera] EXTERNAL_WEBCAM_URL must start with http(s):// or rtsp://; ignoring invalid value.${NC}" >&2
    echo ""
    return
  fi

  if is_loopback_camera_url "${configured_url}"; then
    echo -e "${YELLOW}[camera] EXTERNAL_WEBCAM_URL points to sidecar endpoint; ignoring to prevent loop.${NC}" >&2
    echo ""
    return
  fi

  echo "${configured_url}"
}

detect_go2rtc_stream_url() {
  local go2rtc_port="1984" streams_json camera_url hostname host_ip printer_ip
  local -a non_printer_urls=()

  if ! command -v curl >/dev/null 2>&1; then
    return
  fi

  host_ip="$(read_env_value "HOST_IP")"
  printer_ip="$(read_env_value "PRINTER_IP")"
  hostname="$(hostname -s 2>/dev/null || echo localhost)"

  # Query go2rtc /api/streams endpoint
  streams_json="$(curl --max-time 3 -fsS "http://localhost:${go2rtc_port}/api/streams" 2>/dev/null || true)"

  if [[ -z "${streams_json}" ]]; then
    return
  fi

  # Extract all producer URLs from go2rtc config (only http/rtsp/rtmp, skip exec: commands)
  while IFS= read -r camera_url; do
    [[ -z "${camera_url}" ]] && continue

    # Only accept http, https, rtsp, rtmp URLs (real streaming sources, not exec commands)
    if [[ ! "${camera_url}" =~ ^https?:// && ! "${camera_url}" =~ ^rtsp:// && ! "${camera_url}" =~ ^rtmp:// ]]; then
      continue
    fi

    # Skip sidecar/loopback URLs
    if is_loopback_camera_url "${camera_url}"; then
      continue
    fi

    # Skip placeholder values
    if [[ "${camera_url}" == CHANGE_ME* ]]; then
      continue
    fi

    # Categorize: skip printer URLs (will use detect_printer_stream_url if needed)
    if [[ -n "${printer_ip}" && "${camera_url}" =~ ${printer_ip} ]]; then
      continue
    fi

    # Check if same host as this script
    if [[ -n "${host_ip}" && "${camera_url}" =~ ${host_ip} ]]; then
      # Same host, might be valid external camera on this host
      non_printer_urls+=("${camera_url}")
      continue
    fi

    # Different host = valid external camera source
    non_printer_urls+=("${camera_url}")
  done < <(printf '%s' "${streams_json}" | grep -o '"url":"[^"]*"' | sed 's/"url":"\([^"]*\)"/\1/' | sort -u)

  # Return first non-printer external camera
  if [[ ${#non_printer_urls[@]} -gt 0 ]]; then
    echo "${non_printer_urls[0]}"
  fi
}

detect_printer_stream_url() {
  local configured_url printer_ip host_ip candidate snapshot_url moonraker_json moonraker_stream
  local -a candidates
  local -a relative_bases
  local sig

  configured_url="$(read_env_value "PRINTER_WEBCAM_URL")"
  printer_ip="$(read_env_value "PRINTER_IP")"
  host_ip="$(read_env_value "HOST_IP")"

  if [[ -n "${configured_url}" ]]; then
    if ! is_loopback_camera_url "${configured_url}"; then
      echo "${configured_url}"
      return
    fi
  fi

  # If webcam is served by sidecar host (for example external webcam service on HOST_IP)
  if [[ -n "${host_ip}" ]]; then
    candidates+=(
      "http://${host_ip}:8080/?action=stream"
      "http://${host_ip}:10088/?action=stream"
      "http://${host_ip}/webcam/?action=stream"
      "http://${host_ip}:8080/webcam/?action=stream"
      "http://${host_ip}:10088/webcam/?action=stream"
    )
  fi

  if [[ -n "${printer_ip}" ]]; then
    moonraker_json="$(curl --max-time 4 -fsS "http://${printer_ip}:7125/server/webcams/list" 2>/dev/null || true)"
    moonraker_stream="$(printf '%s' "${moonraker_json}" | tr -d '\n' | grep -o '"stream_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"stream_url"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')"
    moonraker_stream="$(printf '%s' "${moonraker_stream}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [[ -n "${moonraker_stream}" ]]; then
      if [[ "${moonraker_stream}" =~ ^https?:// ]]; then
        if ! is_loopback_camera_url "${moonraker_stream}"; then
          candidates+=("${moonraker_stream}")
        fi
      elif [[ "${moonraker_stream}" == /* ]]; then
        if [[ ! "${moonraker_stream}" =~ ^/camera/ ]]; then
          relative_bases=(
            "http://${printer_ip}"
            "http://${printer_ip}:10088"
            "http://${printer_ip}:8080"
          )
          for base in "${relative_bases[@]}"; do
            candidates+=("${base}${moonraker_stream}")
          done
        fi
      fi
    fi

    candidates+=(
      "http://${printer_ip}/webcam/?action=stream"
      "http://${printer_ip}:10088/webcam/?action=stream"
      "http://${printer_ip}:7125/webcam/?action=stream"
      "http://${printer_ip}:10088/?action=stream"
      "http://${printer_ip}:8080/?action=stream"
    )
  fi

  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo ""
    return
  fi

  if command -v curl >/dev/null 2>&1; then
    for candidate in "${candidates[@]}"; do
      if is_loopback_camera_url "${candidate}"; then
        continue
      fi

      snapshot_url="${candidate/\?action=stream/?action=snapshot}"
      if curl --max-time 4 -fsS -o /tmp/qidi_camera_probe.jpg "${snapshot_url}" 2>/dev/null; then
        sig="$(head -c 2 /tmp/qidi_camera_probe.jpg 2>/dev/null | od -An -t x1 | tr -d ' \n')"
        if [[ "${sig}" == "ffd8" ]]; then
          echo "${candidate}"
          return
        fi
      fi
    done
    rm -f /tmp/qidi_camera_probe.jpg >/dev/null 2>&1 || true
  fi

  echo ""
}

update_go2rtc_stream_source() {
  local camera_mode="$1"
  local stream_source_url="$2"
  local stream_cmd tmp

  if [[ ! -f "${GO2RTC_CONFIG_FILE}" ]]; then
    echo -e "${YELLOW}[camera] go2rtc config not found at ${GO2RTC_CONFIG_FILE}, skipping stream source update.${NC}"
    return
  fi

  if [[ "${camera_mode}" == "printer" || "${camera_mode}" == "external" ]]; then
    stream_cmd="    - \"${stream_source_url}\""
    echo -e "${GREEN}[camera] Configuring go2rtc to use ${camera_mode} stream: ${stream_source_url}${NC}"
  elif [[ "${camera_mode}" == "fallback" ]]; then
    # Safe fallback stream for no-camera environments (WSL/macOS/no USB passthrough)
    stream_cmd='    - "exec:ffmpeg -hide_banner -loglevel error -f lavfi -re -i color=c=black:s=1280x720:r=2 -c:v mjpeg -q:v 5 -f mjpeg -"'
    echo -e "${YELLOW}[camera] No real camera device available; configuring synthetic fallback stream.${NC}"
  else
    stream_cmd='    - "exec:ffmpeg -hide_banner -loglevel error -f v4l2 -input_format mjpeg -video_size 1920x1080 -framerate 30 -i /dev/video0 -c:v mjpeg -q:v 2 -f mjpeg -"'
    echo -e "${GREEN}[camera] Configuring go2rtc to use V4L2 camera input (/dev/video0 in container).${NC}"
  fi

  tmp="$(mktemp)"
  awk -v repl="${stream_cmd}" '
    BEGIN { in_block=0; replaced=0 }
    /^  qidi_plus4:/ {
      in_block=1
      print
      next
    }
    /^  qidi_plus4_h264:/ {
      in_block=0
      print
      next
    }
    in_block && /^    - / && replaced==0 {
      print repl
      replaced=1
      next
    }
    { print }
  ' "${GO2RTC_CONFIG_FILE}" > "${tmp}"

  mv "${tmp}" "${GO2RTC_CONFIG_FILE}"
  echo -e "${GREEN}[camera] Updated stream source in ${GO2RTC_CONFIG_FILE}${NC}"
}

main() {
  local platform camera_device camera_mode stream_source_url printer_stream_url external_stream_url camera_source
  platform="$(detect_platform)"
  camera_device=""
  camera_mode="fallback"
  stream_source_url=""
  printer_stream_url=""
  external_stream_url=""
  camera_source="$(read_env_value "CAMERA_SOURCE")"
  camera_source="${camera_source:-auto}"

  case "${platform}" in
    linux)
      camera_device="$(detect_linux_video_device)"
      if [[ -z "${camera_device}" ]]; then
        camera_device="/dev/null"
        camera_mode="fallback"
        echo -e "${YELLOW}[camera] No /dev/video* found. Using fallback ${camera_device}.${NC}"
      else
        camera_mode="physical"
        echo -e "${GREEN}[camera] Detected Linux camera device: ${camera_device}${NC}"
      fi
      ;;
    wsl)
      camera_device="$(detect_linux_video_device)"
      if [[ -z "${camera_device}" ]]; then
        camera_device="/dev/null"
        camera_mode="fallback"
        echo -e "${YELLOW}[camera] WSL2 detected, but no /dev/video* device exposed.${NC}"
        echo -e "${BLUE}[camera] Tip: attach USB camera from Windows using usbipd, then re-run make up-camera.${NC}"
      else
        camera_mode="physical"
        echo -e "${GREEN}[camera] Detected WSL camera device: ${camera_device}${NC}"
      fi
      ;;
    macos)
      camera_device="/dev/null"
      camera_mode="fallback"
      echo -e "${YELLOW}[camera] macOS detected. Docker Desktop doesn't expose host USB /dev/video devices directly.${NC}"
      echo -e "${BLUE}[camera] Using fallback ${camera_device}. For real video input, use EXTERNAL_WEBCAM_URL in .env.${NC}"
      ;;
    *)
      camera_device="/dev/null"
      camera_mode="fallback"
      echo -e "${YELLOW}[camera] Unknown platform. Using fallback ${camera_device}.${NC}"
      ;;
  esac

  if [[ "${camera_mode}" == "fallback" ]]; then
    case "${camera_source}" in
      auto)
        external_stream_url="$(detect_external_stream_url)"
        if [[ -n "${external_stream_url}" ]]; then
          camera_mode="external"
          stream_source_url="${external_stream_url}"
          echo -e "${GREEN}[camera] No local /dev/video* found, using EXTERNAL_WEBCAM_URL stream.${NC}"
        else
          # Try to discover from go2rtc's API if container is running
          external_stream_url="$(detect_go2rtc_stream_url)"
          if [[ -n "${external_stream_url}" ]]; then
            camera_mode="external"
            stream_source_url="${external_stream_url}"
            echo -e "${GREEN}[camera] Auto-discovered camera from go2rtc: ${external_stream_url}${NC}"
          else
            printer_stream_url="$(detect_printer_stream_url)"
            if [[ -n "${printer_stream_url}" ]]; then
              camera_mode="printer"
              stream_source_url="${printer_stream_url}"
              echo -e "${GREEN}[camera] No local /dev/video* found, but printer webcam stream is reachable.${NC}"
            fi
          fi
        fi
        ;;
      external)
        external_stream_url="$(detect_external_stream_url)"
        if [[ -n "${external_stream_url}" ]]; then
          camera_mode="external"
          stream_source_url="${external_stream_url}"
          echo -e "${GREEN}[camera] CAMERA_SOURCE=external, using EXTERNAL_WEBCAM_URL.${NC}"
        else
          # Fallback to go2rtc discovery
          external_stream_url="$(detect_go2rtc_stream_url)"
          if [[ -n "${external_stream_url}" ]]; then
            camera_mode="external"
            stream_source_url="${external_stream_url}"
            echo -e "${GREEN}[camera] CAMERA_SOURCE=external, auto-discovered from go2rtc: ${external_stream_url}${NC}"
          else
            echo -e "${YELLOW}[camera] CAMERA_SOURCE=external but no camera found. Using fallback stream.${NC}"
          fi
        fi
        ;;
      printer)
        printer_stream_url="$(detect_printer_stream_url)"
        if [[ -n "${printer_stream_url}" ]]; then
          camera_mode="printer"
          stream_source_url="${printer_stream_url}"
          echo -e "${GREEN}[camera] CAMERA_SOURCE=printer, using printer webcam stream.${NC}"
        else
          echo -e "${YELLOW}[camera] CAMERA_SOURCE=printer but printer stream not reachable. Using fallback stream.${NC}"
        fi
        ;;
      physical)
        echo -e "${YELLOW}[camera] CAMERA_SOURCE=physical and no /dev/video* found. Using fallback stream.${NC}"
        ;;
      *)
        echo -e "${YELLOW}[camera] Unknown CAMERA_SOURCE=${camera_source}. Falling back to auto mode behavior.${NC}"
        external_stream_url="$(detect_external_stream_url)"
        if [[ -n "${external_stream_url}" ]]; then
          camera_mode="external"
          stream_source_url="${external_stream_url}"
        else
          external_stream_url="$(detect_go2rtc_stream_url)"
          if [[ -n "${external_stream_url}" ]]; then
            camera_mode="external"
            stream_source_url="${external_stream_url}"
          else
            printer_stream_url="$(detect_printer_stream_url)"
            if [[ -n "${printer_stream_url}" ]]; then
              camera_mode="printer"
              stream_source_url="${printer_stream_url}"
            fi
          fi
        fi
        ;;
    esac
  fi

  upsert_env_var "${ENV_FILE}" "CAMERA_DEVICE" "${camera_device}"
  upsert_env_var "${ENV_FILE}" "CAMERA_SOURCE" "${camera_source}"
  upsert_env_var "${ENV_FILE}" "CAMERA_MODE" "${camera_mode}"
  if [[ -n "${external_stream_url}" ]]; then
    upsert_env_var "${ENV_FILE}" "EXTERNAL_WEBCAM_URL" "${external_stream_url}"
  fi
  if [[ -n "${printer_stream_url}" ]]; then
    upsert_env_var "${ENV_FILE}" "PRINTER_WEBCAM_URL" "${printer_stream_url}"
  fi

  update_go2rtc_stream_source "${camera_mode}" "${stream_source_url}"
  echo -e "${GREEN}[camera] Saved CAMERA_DEVICE=${camera_device} and CAMERA_MODE=${camera_mode} to ${ENV_FILE}${NC}"
}

main "$@"
