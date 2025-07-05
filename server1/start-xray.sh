#!/bin/sh

echo "Starting Xray VMess Server..."
echo "Server UUID: $(grep -o '"uuid":[^,]*' /etc/xray/config.json | cut -d'"' -f4 || echo "550e8400-e29b-41d4-a716-446655440000")"
echo "Listening on port 443 (VMess)"

if [ -x /usr/local/bin/xray ]; then
    exec /usr/local/bin/xray -c /etc/xray/config.json
else
    echo "Xray not available, starting fallback server"
    exec nc -l -p 443
fi 