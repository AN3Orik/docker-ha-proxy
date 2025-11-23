#!/bin/bash

cat > /usr/local/etc/haproxy/haproxy.cfg <<'EOF'
global
    log stdout format raw local0
    maxconn 4096

defaults
    log global
    mode tcp
    option tcplog
    option abortonclose
    timeout connect 5s
    timeout client 1h
    timeout server 1h
    retries 3

EOF

# Process PROXY_ environment variables
env | grep '^PROXY_' | sort | while IFS='=' read -r name value; do
    listen_port=$(echo "$name" | sed 's/PROXY_//')
    target_host=$(echo "$value" | cut -d':' -f1)
    target_port=$(echo "$value" | cut -d':' -f2)
    options=$(echo "$value" | cut -d':' -f3-)
    
    # Create frontend
    echo "frontend tcp_front_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    
    if [ "$options" = "proxy_protocol" ]; then
        echo "    bind *:${listen_port} accept-proxy" >> /usr/local/etc/haproxy/haproxy.cfg
    else
        echo "    bind *:${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    fi
    
    echo "    default_backend tcp_back_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "" >> /usr/local/etc/haproxy/haproxy.cfg
    
    # Create backend
    echo "backend tcp_back_${listen_port}" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "    server server1 ${target_host}:${target_port} check" >> /usr/local/etc/haproxy/haproxy.cfg
    echo "" >> /usr/local/etc/haproxy/haproxy.cfg
done

echo "Generated HAProxy configuration:"
cat /usr/local/etc/haproxy/haproxy.cfg

# Validate configuration
haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Start HAProxy in foreground mode
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
