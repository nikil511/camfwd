# camfwd — Remote Camera RTSP & HTTP Gateway (Balena Tunnel + Tailscale)

Lightweight `docker-compose` gateway designed for low-power edge devices (such as BeagleBone Black / Raspberry Pi running balenaOS) to expose LAN IP cameras (RTSP video streams + HTTP Web UIs / ISAPI) to a remote **Frigate NVR** over either:

1. **Balena Tunnel (`balena tunnel`)** & **Balena Public Device URL**
2. **Tailscale** (both direct Tailscale IP port-forwarding and full LAN subnet routing)

---

## Architecture & Exposed Ports

`camfwd` runs two host-networked services (`proxy` using `haproxy:2.8-alpine` and `tailscale` using `tailscale:stable`):

| Local / Tunnel / Tailscale Port | Protocol | Target Env Variable | Description |
| :--- | :--- | :--- | :--- |
| **`:80` (`/camera1`)** | HTTP | `CAMERA1_HOST` | Camera 1 Web UI / ISAPI via path prefix (works with Balena Public URL) |
| **`:80` (`/camera2`)** | HTTP | `CAMERA2_HOST` | Camera 2 Web UI / ISAPI via path prefix (works with Balena Public URL) |
| **`:80` (`/frigate`)** | HTTP | `FRIGATE_HOST` | Local Frigate instance Web UI via path prefix |
| **`:80` (`/`)** | HTTP | `ROUTER_HOST` | Default fallback route (LAN router UI) |
| **`:8081`** | HTTP | `CAMERA1_HOST` | Dedicated root-path HTTP proxy for Camera 1 Web UI & ISAPI |
| **`:8082`** | HTTP | `CAMERA2_HOST` | Dedicated root-path HTTP proxy for Camera 2 Web UI & ISAPI |
| **`:5541` & `:8554`** | TCP (RTSP) | `CAMERA1_RTSP_HOST` | **Camera 1 RTSP stream** (`rtsp://<user>:<pass>@<host>:5541/Streaming/Channels/101`) |
| **`:5542` & `:8555`** | TCP (RTSP) | `CAMERA2_RTSP_HOST` | **Camera 2 RTSP stream** (`rtsp://<user>:<pass>@<host>:5542/Streaming/Channels/101`) |

---

## Configuration (balenaCloud Fleet / Device Environment Variables)

No LAN IP addresses or credentials are hardcoded in this repository. Configure the following variables in **balenaCloud**:

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `CAMERA1_HOST` | `<cam1-lan-ip>:80` | Camera 1 HTTP address and port |
| `CAMERA1_RTSP_HOST` | `<cam1-lan-ip>:554` | Camera 1 RTSP address and port |
| `CAMERA2_HOST` | `<cam2-lan-ip>:80` | Camera 2 HTTP address and port |
| `CAMERA2_RTSP_HOST` | `<cam2-lan-ip>:554` | Camera 2 RTSP address and port |
| `FRIGATE_HOST` | `<frigate-lan-ip>:5000` | Local Frigate NVR HTTP address and port |
| `ROUTER_HOST` | `<router-lan-ip>:80` | Local router HTTP address and port |
| `TS_AUTHKEY` | `tskey-auth-...` | *(Optional)* Tailscale auth key (if omitted, login URL is printed in logs) |
| `TS_ROUTES` | `192.168.0.0/24` | *(Optional)* LAN CIDR subnet advertised to Tailscale |
| `TS_HOSTNAME` | `camfwd` | *(Optional)* Tailscale node hostname |

---

## Connecting a Remote Frigate NVR

### Option A: Via Tailscale (Recommended for 24/7 NVR)

Once `tailscale` is authenticated, any remote Frigate node on your Tailnet can pull the RTSP streams directly using `camfwd`'s Tailscale IP (`100.x.y.z` or `camfwd`) **without** even needing `--accept-routes` on the Frigate host:

```yaml
go2rtc:
  streams:
    camera_202:
      - rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@camfwd:5541/Streaming/Channels/101
    camera_200:
      - rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@camfwd:5542/Streaming/Channels/101
```

If subnet routing (`TS_ROUTES`) is approved in the Tailscale Admin Console and `--accept-routes` is enabled on the remote Frigate node, you can also reach the cameras directly by their LAN IPs.

### Option B: Via `balena tunnel` (Works Immediately Without Tailscale)

On the machine running the remote Frigate NVR (or your workstation), open tunnels to the `camfwd` device UUID (`<DEVICE_UUID>`):

```bash
# Forward Camera 1 RTSP (:5541), Camera 2 RTSP (:5542), and Camera HTTP UIs (:8081, :8082)
balena tunnel <DEVICE_UUID> -p 5541:5541 -p 5542:5542 -p 8081:8081 -p 8082:8082
```

Then point your remote Frigate (or VLC / `ffplay`) to:
- **Camera 1 RTSP:** `rtsp://<user>:<pass>@127.0.0.1:5541/Streaming/Channels/101`
- **Camera 2 RTSP:** `rtsp://<user>:<pass>@127.0.0.1:5542/Streaming/Channels/101`
- **Camera 1 HTTP / ISAPI:** `http://127.0.0.1:8081`
- **Camera 2 HTTP / ISAPI:** `http://127.0.0.1:8082`
