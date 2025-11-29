#!/bin/bash

# Set TCP keepalive parameters to match game server settings
# KEEP_ALIVE_IDLE=10s, KEEP_ALIVE_INTERVAL=3s, KEEP_ALIVE_COUNT=5
sysctl -w net.ipv4.tcp_keepalive_time=10 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_intvl=3 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_probes=5 >/dev/null 2>&1 || true

cat > /usr/local/etc/haproxy/haproxy.cfg <<'EOF'
global
    log stdout format raw local0
    maxconn 4096

defaults
    log global
    mode tcp
    option tcplog
    option clitcpka
    option srvtcpka
    timeout connect 5s
    timeout client 25s
    timeout server 25s
    timeout tunnel 1h
    timeout client-fin 10s
    timeout server-fin 10s
    retries 2

EOF

# Respect global disable flag for health checks
DISABLE_HEALTH_CHECKS=${DISABLE_HEALTH_CHECKS:-false}

# Process PROXY_ environment variables
env | grep '^PROXY_' | sort | while IFS='=' read -r name value; do
    listen_port=$(echo "$name" | sed 's/PROXY_//')
    target_host=$(echo "$value" | cut -d':' -f1)
    target_port=$(echo "$value" | cut -d':' -f2)
    options=$(echo "$value" | cut -d':' -f3-)

    # normalize options: comma or space separated
    opts_csv=$(echo "$options" | sed 's/:/,/g' | sed 's/;/,/g')

    # Create frontend
    echo "frontend tcp_front_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg

    if echo "${opts_csv}" | tr ',' '\n' | grep -q '^\s*proxy_protocol\s*$'; then
        echo "    bind *:${listen_port} accept-proxy tcp-ut 23000" >> /usr/local/etc/haproxy/haproxy.cfg
    else
        echo "    bind *:${listen_port} tcp-ut 23000" >> /usr/local/etc/haproxy/haproxy.cfg
    fi

    echo "    default_backend tcp_back_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "" >> /usr/local/etc/haproxy/haproxy.cfg

    # Build backend server line with optional flags
    server_line="server server1 ${target_host}:${target_port} tcp-ut 23000"

    # send-proxy to backend (enabled by default for PROXY Protocol v2)
    # can be disabled with no_proxy option
    send_proxy_enabled=true
    if echo "${opts_csv}" | tr ',' '\n' | grep -q '^\s*no_proxy\s*$'; then
        send_proxy_enabled=false
    fi

    if [ "${send_proxy_enabled}" = "true" ]; then
        # check if user explicitly requested v1
        if echo "${opts_csv}" | tr ',' '\n' | grep -q '^\s*send-proxy-v1\s*$\|^\s*send-proxy\s*$'; then
            server_line+=" send-proxy"
        else
            # default to v2
            proxy_v2_token=" send-proxy-v2"
            
            # Check for proxy_auth option to add TLV authentication
            if echo "${opts_csv}" | tr ',' '\n' | grep -q 'proxy_auth='; then
                auth_token=$(echo "${opts_csv}" | tr ',' '\n' | grep 'proxy_auth=' | head -n1 | cut -d'=' -f2)
                if [ -n "${auth_token}" ]; then
                    # Add TLV (0xE0) with authentication token
                    proxy_v2_token+=" set-proxy-v2-tlv-fmt(0xE0) %[str(${auth_token})]"
                fi
            fi
            
            server_line+="${proxy_v2_token}"
        fi
    fi

    # Health check handling: disabled by default, can be enabled globally or per-backend
    enable_check=false
    
    # Global enable flag
    if [ "${ENABLE_HEALTH_CHECKS}" = "true" ] || [ "${ENABLE_HEALTH_CHECKS}" = "1" ]; then
        enable_check=true
    fi
    
    # Per-backend enable/disable override
    if echo "${opts_csv}" | tr ',' '\n' | grep -q '^\s*check\s*$'; then
        enable_check=true
    fi
    if echo "${opts_csv}" | tr ',' '\n' | grep -q '^\s*no_check\s*$'; then
        enable_check=false
    fi

    if [ "${enable_check}" = "true" ]; then
        # start with plain check
        check_token="check"

        # check interval (ms)
        if echo "${opts_csv}" | tr ',' '\n' | grep -q 'check_interval='; then
            ci=$(echo "${opts_csv}" | tr ',' '\n' | grep 'check_interval=' | head -n1 | cut -d'=' -f2)
            if [ -n "${ci}" ]; then
                check_token+=" inter ${ci}"
            fi
        fi

        if echo "${opts_csv}" | tr ',' '\n' | grep -q 'fall='; then
            fallv=$(echo "${opts_csv}" | tr ',' '\n' | grep 'fall=' | head -n1 | cut -d'=' -f2)
            if [ -n "${fallv}" ]; then
                check_token+=" fall ${fallv}"
            fi
        fi

        if echo "${opts_csv}" | tr ',' '\n' | grep -q 'rise='; then
            risev=$(echo "${opts_csv}" | tr ',' '\n' | grep 'rise=' | head -n1 | cut -d'=' -f2)
            if [ -n "${risev}" ]; then
                check_token+=" rise ${risev}"
            fi
        fi

        server_line+=" ${check_token}"
    fi

    # Write backend
    echo "backend tcp_back_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "    ${server_line}" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "" >> /usr/local/etc/haproxy/haproxy.cfg
done

echo "Generated HAProxy configuration:"
cat /usr/local/etc/haproxy/haproxy.cfg

# Validate configuration
haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Start HAProxy in foreground mode
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
