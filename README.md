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
  - PROXY_<LISTEN_PORT>=<TARGET_HOST>:<TARGET_PORT>
  - PROXY_<LISTEN_PORT>=<TARGET_HOST>:<TARGET_PORT>:proxy_protocol
```

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

#### Redis Proxy

```yaml
ports:
  - "6379:6379"
environment:
  - PROXY_6379=redis-server.example.com:6379
```

#### With Proxy Protocol

```yaml
ports:
  - "7788:7788"
environment:
  - PROXY_7788=backend.example.com:7798:proxy_protocol
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