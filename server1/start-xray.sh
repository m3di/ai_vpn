#!/bin/sh

echo "=========================================="
echo "Starting Xray VMess Server..."
echo "=========================================="

# Extract configuration information
SERVER_UUID=$(grep -o '"id":[^,]*' /etc/xray/config.json | cut -d'"' -f4 || echo "550e8400-e29b-41d4-a716-446655440000")
SERVER_PORT=$(grep -o '"port":[^,]*' /etc/xray/config.json | cut -d':' -f2 | tr -d ' ' || echo "443")
SECURITY_TYPE=$(grep -o '"security":[^,]*' /etc/xray/config.json | cut -d'"' -f4 || echo "auto")
NETWORK_TYPE=$(grep -o '"network":[^,]*' /etc/xray/config.json | cut -d'"' -f4 || echo "tcp")
SECURITY_LAYER=$(grep -A20 '"streamSettings"' /etc/xray/config.json | grep -o '"security":[^,]*' | head -1 | cut -d'"' -f4 || echo "none")

echo "V2Ray VMess Server Configuration:"
echo "  Server UUID: $SERVER_UUID"
echo "  Server Port: $SERVER_PORT"
echo "  Security: $SECURITY_TYPE"
echo "  Network: $NETWORK_TYPE"
echo "  Transport Security: $SECURITY_LAYER"

if [ "$SECURITY_LAYER" = "tls" ]; then
    echo "  TLS Configuration: Enabled"
    echo "  Certificate: /etc/xray/server.crt"
    echo "  Private Key: /etc/xray/server.key"
    if [ -f /etc/xray/server.crt ]; then
        echo "  Certificate Subject: $(openssl x509 -in /etc/xray/server.crt -noout -subject 2>/dev/null | sed 's/subject=//' || echo 'Could not read certificate')"
        echo "  Certificate Expiry: $(openssl x509 -in /etc/xray/server.crt -noout -enddate 2>/dev/null | sed 's/notAfter=//' || echo 'Could not read certificate')"
    fi
fi

echo ""
echo "V2Ray Client Configuration Information:"
echo "=========================================="
echo "Server Address: [YOUR_SERVER_IP]"
echo "Server Port: $SERVER_PORT"
echo "User ID (UUID): $SERVER_UUID"
echo "Alter ID: 0"
echo "Security: $SECURITY_TYPE"
echo "Network: $NETWORK_TYPE"

if [ "$SECURITY_LAYER" = "tls" ]; then
    echo "Transport Security: TLS"
    echo "TLS Server Name: cloudflare.com"
    echo "TLS Allow Insecure: true (for testing)"
    echo ""
    echo "V2Ray Client JSON Configuration:"
    echo "================================"
    cat << 'EOF'
{
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "[YOUR_SERVER_IP]",
            "port": 443,
            "users": [
              {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": true,
          "serverName": "cloudflare.com"
        },
        "tcpSettings": {
          "header": {
            "type": "http",
            "request": {
              "version": "1.1",
              "method": "GET",
              "path": ["/", "/index.html"],
              "headers": {
                "Host": ["cloudflare.com"],
                "User-Agent": ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
              }
            }
          }
        }
      }
    }
  ]
}
EOF
else
    echo "Transport Security: None"
    echo ""
    echo "V2Ray Client JSON Configuration:"
    echo "================================"
    cat << 'EOF'
{
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "[YOUR_SERVER_IP]",
            "port": 443,
            "users": [
              {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ]
}
EOF
fi

echo ""
echo "=========================================="
echo "Anti-Censorship Features:"
if [ "$SECURITY_LAYER" = "tls" ]; then
    echo "  ✓ TLS Obfuscation: Enabled"
    echo "  ✓ HTTP Header Masquerading: Enabled"
    echo "  ✓ Certificate Spoofing: cloudflare.com"
    echo "  ✓ Traffic Pattern Obfuscation: Enabled"
    echo "  ✓ Port 443 (HTTPS): Standard port for evasion"
else
    echo "  ✗ TLS Obfuscation: Disabled"
    echo "  ✗ HTTP Header Masquerading: Disabled"
    echo "  ✗ Certificate Spoofing: Disabled"
    echo "  ⚠ Basic VMess: May be detectable by DPI"
fi
echo "=========================================="
echo ""

if [ -x /usr/local/bin/xray ]; then
    echo "Starting Xray server..."
    echo "Configuration file: /etc/xray/config.json"
    echo "Log files: /var/log/xray/"
    echo ""
    exec /usr/local/bin/xray -c /etc/xray/config.json
else
    echo "ERROR: Xray not found at /usr/local/bin/xray"
    echo "Starting fallback server on port 443"
    exec nc -l -p 443
fi 