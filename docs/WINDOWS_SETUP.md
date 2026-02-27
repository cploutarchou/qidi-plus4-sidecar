Windows camera notes — make the camera available to the stack
=============================================================

This project is designed to run on a Linux host and expects a Video4Linux device at /dev/video0
inside the container. On Windows you have two practical ways to get a camera working:

1) Pass the USB camera into WSL2 (recommended when continuing to use the provided Docker Compose stack)
2) Run a small Windows-side streamer (ffmpeg) and have go2rtc pull an RTSP/MJPEG stream

Option 1 — usbipd-win (attach USB camera to WSL2)
Prereqs: Windows 10/11 with WSL2, a WSL distro (e.g. Ubuntu), Docker Desktop with WSL2 integration, and usbipd-win.

Steps (PowerShell as Administrator):

```powershell
usbipd.exe wsl list
usbipd.exe wsl attach --busid <BUSID>
```

Then open your WSL distro (bash) and verify the device appears:

```bash
ls -la /dev/video*
docker compose up -d
```

Notes:

- Docker Desktop must be using the WSL2 backend and integration enabled for the distro you attach the device to.
- When finished, detach with:

```powershell
usbipd.exe wsl detach --busid <BUSID>
```

Option 2 — Run a Windows streamer and point go2rtc at the stream
Install ffmpeg on Windows and publish your camera as RTSP (or MJPEG/HTTP) that the container can reach.

Simple ffmpeg push example (publishes to an RTSP server that accepts publishers):

```powershell
ffmpeg -f dshow -i video="<Your Camera Name>" -c:v libx264 -preset veryfast -f rtsp rtsp://<rtsp-server-host>:8554/qidi_plus4
```

Alternative — run go2rtc natively on Windows (advanced):
If you prefer not to use Docker on Windows, build/download a Windows binary of go2rtc and replace the v4l2 ffmpeg input
with a DirectShow input (ffmpeg -f dshow -i video="Your Camera Name"). This requires changing `go2rtc.yaml` accordingly.

If you'd like, I can:

- add a sample Docker Compose service for an RTSP server to the repo (so Windows ffmpeg can push into it), or
- modify `go2rtc/go2rtc.yaml` to include an example RTSP source (commented) for Windows-hosted streams.

Summary: the easiest path to get the existing stack working on Windows is to attach the USB camera to WSL2 using usbipd-win and run the compose stack from inside that WSL distro (so /dev/video0 is available to the containers).
