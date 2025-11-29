# HAProxy TCP Proxy

Docker container with HAProxy for TCP/UDP stream proxying. Configuration via environment variables in docker-compose.yml.

## Quick Start

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  haproxy-stream-proxy:
    image: ghcr.io/an3orik/docker-ha-proxy:latest
    container_name: haproxy-stream-proxy
    restart: unless-stopped
    ports:
      - "3306:3306"
      - "5432:5432"
    environment:
      - PROXY_3306=mysql-server.example.com:3306
      - PROXY_5432=postgres-server.example.com:5432
```

Run:
```bash
docker-compose up -d
```

## Configuration

### Environment Variable Format

```yaml
environment:
  - PROXY_<LISTEN_PORT>=<TARGET_HOST>:<TARGET_PORT>[:OPTIONS]
```

**Default Behavior:**
- PROXY Protocol v2 headers are sent to backend servers by default (preserves client IP)
- Health checks are disabled by default (prevents connection spam to game servers)

#### Available Options (comma-separated)

- `proxy_protocol` - Accept PROXY Protocol from incoming clients (on bind)
- `send-proxy-v1` - Send PROXY Protocol v1 to backend (instead of default v2)
- `no_proxy` - Disable sending PROXY headers to backend
- `proxy_auth=<token>` - Add authentication token to PROXY Protocol v2 TLV (0xE0)
- `check` - Enable health checks for this backend
- `no_check` - Explicitly disable health checks (redundant, for clarity)
- `check_interval=<ms>` - Health check interval in milliseconds (requires `check`)
- `fall=<n>` - Number of failed checks before marking server down (requires `check`)
- `rise=<n>` - Number of successful checks before marking server up (requires `check`)

**Global Options:**
- `ENABLE_HEALTH_CHECKS=true` - Enable health checks for all backends globally

### Examples

#### MySQL/MariaDB Proxy

```yaml
ports:
  - "3306:3306"
environment:
  - PROXY_3306=mysql-server.example.com:3306
```

#### PostgreSQL Proxy

```yaml
ports:
  - "5432:5432"
environment:
  - PROXY_5432=postgres-server.example.com:5432
```

#### Minecraft/Game Server (without PROXY Protocol)

If your backend doesn't support PROXY Protocol:

```yaml
ports:
  - "25565:25565"
environment:
  - PROXY_25565=game-server.example.com:25565:no_proxy
```

#### With Incoming PROXY Protocol

If clients send PROXY Protocol headers to HAProxy:

```yaml
ports:
  - "7788:7788"
environment:
  - PROXY_7788=backend.example.com:7798:proxy_protocol
```

#### Enable Health Checks

Health checks are disabled by default. To enable globally:

```yaml
environment:
  - ENABLE_HEALTH_CHECKS=true
  - PROXY_25565=game-server.example.com:25565
```

Or enable per-backend:

```yaml
environment:
  - PROXY_25565=game-server.example.com:25565:check
```

#### Custom Health Check Settings

```yaml
environment:
  - PROXY_25565=game-server.example.com:25565:check,check_interval=30000,fall=3,rise=2
```

#### PROXY Protocol v2 with Authentication (Security)

Prevent IP spoofing by adding authentication token to PROXY Protocol v2 headers:

```yaml
environment:
  - PROXY_7788=game-server.example.com:7788:proxy_auth=your-secret-token-here
```

HAProxy will send authentication token in TLV field `0xE0`. Backend must validate this token:

**Netty/Java Backend Example:**
```java
// In your pipeline handler
HAProxyMessage msg = (HAProxyMessage) in.readInbound();
List<HAProxyTLV> tlvs = msg.tlvs();
boolean authenticated = false;

for (HAProxyTLV tlv : tlvs) {
    if (tlv.typeByteValue() == (byte)0xE0) {
        String token = tlv.content().toString(StandardCharsets.UTF_8);
        if (token.equals("your-secret-token-here")) {
            authenticated = true;
            break;
        }
    }
}

if (!authenticated) {
    ctx.close();
    return;
}
```

**Security Benefits:**
- Prevents malicious actors in same datacenter from spoofing client IPs
- No TLS overhead (authentication happens at protocol level)
- Simple token-based validation

**Note:** Use environment variables for tokens, never hardcode in compose files:
```yaml
environment:
  - PROXY_7788=game-server.example.com:7788:proxy_auth=${HAPROXY_AUTH_TOKEN}
```

#### Multiple Proxies

```yaml
ports:
  - "3306:3306"
  - "5432:5432"
  - "6379:6379"
  - "27017:27017"
environment:
  - PROXY_3306=mysql.example.com:3306
  - PROXY_5432=postgres.example.com:5432
  - PROXY_6379=redis.example.com:6379
  - PROXY_27017=mongodb.example.com:27017
```

## Docker Run

```bash
docker run -d \
  --name haproxy-stream-proxy \
  -p 3306:3306 \
  -e PROXY_3306=mysql-server:3306 \
  ghcr.io/an3orik/docker-ha-proxy:latest
```

## Applying Changes

After modifying environment variables in `docker-compose.yml`:

```bash
docker-compose up -d --force-recreate
```

## Viewing Logs

```bash
# Container logs (including generated configuration and HAProxy logs)
docker-compose logs haproxy-stream-proxy
```

## Configuration Check

```bash
# View generated HAProxy configuration
docker-compose exec haproxy-stream-proxy cat /usr/local/etc/haproxy/haproxy.cfg

# Verify configuration syntax
docker-compose exec haproxy-stream-proxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

## Building from Source

Clone the repository:
```bash
git clone https://github.com/AN3Orik/docker-ha-proxy.git
cd docker-ha-proxy
```

Build and run:
```bash
docker-compose build
docker-compose up -d
```

## Available Tags

- `latest` - Latest build from main branch
- `v*.*.*` - Specific version releases