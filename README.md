# TON RLDP-HTTP-Proxy (Docker)

Dockerized [TON RLDP-HTTP-Proxy](https://github.com/ton-blockchain/ton) — an HTTP proxy that resolves `.ton` domains over the TON network using the RLDP protocol. This image lets you browse TON Sites (e.g. `http://tonnel.ton`) from any regular browser or HTTP client by routing requests through a local proxy.

**Docker Hub:** [tonnamespace/rldp-http-proxy](https://hub.docker.com/r/tonnamespace/rldp-http-proxy)

---

## How It Works

The container runs the official `rldp-http-proxy` binary from [ton-blockchain/ton](https://github.com/ton-blockchain/ton). It connects to the TON network via liteservers (configured through `global.config.json`), resolves `.ton` domain names via TON DNS, and fetches site content over the RLDP protocol. Locally it exposes an HTTP proxy on port `8080` (mapped to `9080` on the host by default) that you can point your browser or `curl` at.

---

## Quick Start (Step by Step)

### Step 1: Clone the Repository

```bash
git clone https://github.com/TON-Namespace/docker-ton-rldp-http-proxy.git
cd docker-ton-rldp-http-proxy
```

### Step 2: Download `global.config.json`

Download the TON network global config into the project directory:

```bash
curl -o global.config.json https://ton-blockchain.github.io/global.config.json
```

> **Troubleshooting `global.config.json`**
>
> The original `global.config.json` from `ton-blockchain.github.io` should work out of the box in most cases. However, if the proxy fails to start and you see errors related to **syncing** or **liteserver connections**, it is likely caused by unreliable liteservers in the default config.
>
> To fix this:
>
> 1. Register at [https://tonconsole.com](https://tonconsole.com)
> 2. Go to **TON API** section, then **Liteservers**
> 3. Download the `tonapi.io` version of `global.config.json`
> 4. Open both config files — the original one you downloaded and the one from tonconsole
> 5. **Replace** the `"liteservers"` section in the original `global.config.json` with the `"liteservers"` section from the tonconsole config
> 6. Save and use this modified file
>
> **Rate limits on tonconsole liteservers:**
>
> | Plan | Rate Limit | Best For |
> |------|-----------|----------|
> | Free | 1 request/sec | Personal use only |
> | Lite | 50 requests/sec | Sharing the proxy with other clients |
>
> The free plan is perfectly fine if you are running the proxy for yourself. If you plan to share the proxy with multiple users or other services, consider upgrading to the Lite subscription for higher throughput.

### Step 3: Run `prepare.sh`

The `prepare.sh` script automates the initial setup of your proxy node. It does the following:

1. **Generates an ADNL keypair** — Every node on the TON network needs a unique ADNL (Abstract Datagram Network Layer) identity. The script creates a `keyring/` directory and runs the `generate-random-id` tool inside a temporary Docker container to produce a new ADNL private key and its corresponding base64 address.
2. **Prompts you to paste the ADNL address** — After key generation, the script asks you to copy the base64 ADNL address from the output and paste it back. This address is used to identify your proxy node on the network.
3. **Auto-detects your public IP** — The script calls `ipinfo.io/ip` to determine your server's public IP address.
4. **Creates `main.env`** — All collected values (`SERVER_PUBLIC_IP`, `SERVER_ADNL_ADDRESS`, `PORT`, `ADNL_PORT`, etc.) are written into a `main.env` file that `docker-compose.yml` reads at startup.

Run it:

```bash
chmod +x prepare.sh
./prepare.sh
```

After the script finishes, review `main.env` to make sure `SERVER_PUBLIC_IP` is correct (especially if you are behind NAT or a cloud provider).

### Step 4: Start the Proxy

```bash
docker compose up -d
```

This pulls the image (if not built locally), creates the container, mounts `global.config.json` and the `keyring/` directory, loads `main.env`, and starts the RLDP-HTTP-Proxy.

### Step 5: Check Logs

To follow the container logs in real time, use either:

```bash
# If you are in the project directory:
docker compose logs -f

# Or by container name from anywhere:
docker logs -f ton-proxy-gateway
```

You should see output like the proxy connecting to liteservers and starting to listen on port `8080`.

### Step 6: Verify It Works

Test the proxy with `curl` by requesting a `.ton` website through it. For example, to open `tonnel.ton`:

```bash
curl -x localhost:9080 http://tonnel.ton
```

> **Note:** The host port is `9080` (mapped from container port `8080` in `docker-compose.yml`). If you changed the port mapping, adjust accordingly.

If you get back HTML content, the proxy is working correctly.

---

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `8080` (container) / `9080` (host) | TCP | HTTP proxy endpoint — point your browser or `curl` here |
| `3333` | UDP | ADNL port — used for TON network peer-to-peer communication |

Make sure port `3333/udp` is open on your firewall/security group so the proxy can communicate with the TON network.

---

## Environment Variables

These are set automatically by `prepare.sh` in `main.env`, but you can edit them manually:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SERVER_PUBLIC_IP` | Yes | Auto-detected | Your server's public IP address |
| `SERVER_ADNL_ADDRESS` | Yes | Generated | Base64 ADNL address from key generation |
| `PORT` | No | `8080` | HTTP proxy listen port inside the container |
| `ADNL_PORT` | No | `3333` | UDP port for ADNL network communication |
| `CONFIG_PATH` | No | `/ton-proxy/global.config.json` | Path to the global config inside the container |
| `VERBOSITY` | No | — | Log verbosity level (e.g. `DEBUG`) |
| `CLIENT_PORT` | No | — | Client port option for the proxy |
| `LOCAL` | No | — | Local address option |
| `DB` | No | — | Database path option |
| `REMOTE` | No | — | Remote address option |
| `STORAGE_GATEWAY` | No | — | Storage gateway option |
| `PROXY_ALL` | No | — | Proxy all traffic flag |
| `DAEMONIZE` | No | `false` | Run as daemon (not recommended in Docker) |

---

## File Structure

```
docker-ton-rldp-http-proxy/
├── Dockerfile            # Multi-stage build: downloads TON binaries and creates runtime image
├── docker-compose.yml    # Compose config with volume mounts and env file
├── entrypoint.sh         # Container entrypoint: handles key generation mode and proxy startup
├── prepare.sh            # Host-side setup script: generates ADNL keys and creates main.env
├── global.config.json    # TON network config (you provide this)
├── keyring/              # Generated ADNL private keys (created by prepare.sh)
└── main.env              # Environment variables (created by prepare.sh)
```

---

## Related: Host a Website on the TON Network

If you want to **run your own website behind the TON network** (make your site accessible as a `.ton` domain), check out the companion project:

- **Docker Hub:** [tonnamespace/reverse-proxy](https://hub.docker.com/r/tonnamespace/reverse-proxy)
- **GitHub:** [TON-Namespace/docker-ton-reverse-proxy](https://github.com/TON-Namespace/docker-ton-reverse-proxy)

That image runs `rldp-http-proxy` in **reverse proxy mode**, allowing you to serve a regular HTTP backend (e.g. Nginx, Node.js) over the TON network so users can access it via a `.ton` domain.

| Project | Purpose |
|---------|---------|
| **docker-ton-rldp-http-proxy** (this repo) | Browse `.ton` websites — acts as a forward HTTP proxy |
| **docker-ton-reverse-proxy** | Host `.ton` websites — acts as a reverse proxy for your backend |

---

## Building the Image Locally

If you prefer to build from source instead of pulling from Docker Hub:

```bash
docker build -t ton-proxy-client .
```

Then update `docker-compose.yml` to use `image: ton-proxy-client` (which is already the default).

---

## License

This project packages the official TON binaries from [ton-blockchain/ton](https://github.com/ton-blockchain/ton). Refer to the TON repository for licensing details.
