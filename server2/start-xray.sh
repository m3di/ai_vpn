#!/bin/sh

echo "Starting Xray Proxy Chain Server..."
echo "HTTP Proxy: 0.0.0.0:3128"
echo "VMess Outbound to Server1: vpn-server1:443"
echo "VMess UUID: $(grep -o '"id":[^,]*' /etc/xray/config.json | head -1 | cut -d'"' -f4 || echo "550e8400-e29b-41d4-a716-446655440000")"

if [ -x /usr/local/bin/xray ]; then
    exec /usr/local/bin/xray -c /etc/xray/config.json
else
    echo "Xray not available, starting fallback HTTP proxy server"
    exec nc -l -p 3128
fi 