#!/bin/bash

# Test script to verify production deployment URLs
echo "=== Testing Production Deployment URLs ==="
echo ""

REPO_URL="https://github.com/m3di/ai_vpn"
RELEASE_URL="$REPO_URL/releases/latest/download"

echo "Repository: $REPO_URL"
echo "Release URL: $RELEASE_URL"
echo ""

echo "Testing URL accessibility..."
echo ""

# Test server1.tar.gz URL
echo "Testing server1.tar.gz URL:"
echo "  $RELEASE_URL/server1.tar.gz"
curl -I -s "$RELEASE_URL/server1.tar.gz" | head -1
echo ""

# Test server2.tar.gz URL
echo "Testing server2.tar.gz URL:"
echo "  $RELEASE_URL/server2.tar.gz"
curl -I -s "$RELEASE_URL/server2.tar.gz" | head -1
echo ""

# Test README.md URL
echo "Testing README.md URL:"
echo "  $RELEASE_URL/README.md"
curl -I -s "$RELEASE_URL/README.md" | head -1
echo ""

echo "=== Production Deployment Commands ==="
echo ""

cat << 'EOF'
# Server1 Installation
wget https://github.com/m3di/ai_vpn/releases/latest/download/server1.tar.gz
tar -xzf server1.tar.gz && cd server1
chmod +x install.sh && sudo ./install.sh

# Server2 Installation
wget https://github.com/m3di/ai_vpn/releases/latest/download/server2.tar.gz
tar -xzf server2.tar.gz && cd server2
chmod +x install.sh && sudo ./install.sh
EOF

echo ""
echo "Note: URLs will be active after creating your first release with:"
echo "  git tag v1.0.0 && git push origin v1.0.0" 