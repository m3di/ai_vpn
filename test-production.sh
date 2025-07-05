#!/bin/bash

# Test script to verify production Docker deployment
echo "=== Testing Production Docker Deployment ==="
echo ""

DOCKER_REPO="m3di/ai-vpn"
GITHUB_REPO="https://github.com/m3di/ai_vpn"
RELEASE_URL="$GITHUB_REPO/releases/latest/download"

echo "Docker Repository: $DOCKER_REPO"
echo "GitHub Repository: $GITHUB_REPO"
echo "Release URL: $RELEASE_URL"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

echo "Testing Docker image availability..."
echo ""

# Test server1 image
echo "Testing server1 image:"
echo "  docker pull $DOCKER_REPO:server1-latest"
if docker pull $DOCKER_REPO:server1-latest &>/dev/null; then
    echo "✅ Server1 image is available from Docker Hub"
elif docker image inspect $DOCKER_REPO:server1-latest &>/dev/null; then
    echo "✅ Server1 image is available locally"
else
    echo "❌ Server1 image is not available"
    exit 1
fi

# Test server2 image
echo "Testing server2 image:"
echo "  docker pull $DOCKER_REPO:server2-latest"
if docker pull $DOCKER_REPO:server2-latest &>/dev/null; then
    echo "✅ Server2 image is available from Docker Hub"
elif docker image inspect $DOCKER_REPO:server2-latest &>/dev/null; then
    echo "✅ Server2 image is available locally"
else
    echo "❌ Server2 image is not available"
    exit 1
fi

# Test internet server image
echo "Testing internet server image:"
echo "  docker pull $DOCKER_REPO:internet-latest"
if docker pull $DOCKER_REPO:internet-latest &>/dev/null; then
    echo "✅ Internet server image is available from Docker Hub"
elif docker image inspect $DOCKER_REPO:internet-latest &>/dev/null; then
    echo "✅ Internet server image is available locally"
else
    echo "❌ Internet server image is not available"
    exit 1
fi

# Test client image
echo "Testing client image:"
echo "  docker pull $DOCKER_REPO:client-latest"
if docker pull $DOCKER_REPO:client-latest &>/dev/null; then
    echo "✅ Client image is available from Docker Hub"
elif docker image inspect $DOCKER_REPO:client-latest &>/dev/null; then
    echo "✅ Client image is available locally"
else
    echo "❌ Client image is not available"
    exit 1
fi

echo ""
echo "Testing deployment file availability..."
echo ""

# Test docker-compose.server1.yml URL
echo "Testing server1 compose file:"
echo "  $RELEASE_URL/docker-compose.server1.yml"
if curl -I -s -f "$RELEASE_URL/docker-compose.server1.yml" &>/dev/null; then
    echo "✅ Server1 compose file is available"
else
    echo "❌ Server1 compose file is not available"
fi

# Test docker-compose.server2.yml URL
echo "Testing server2 compose file:"
echo "  $RELEASE_URL/docker-compose.server2.yml"
if curl -I -s -f "$RELEASE_URL/docker-compose.server2.yml" &>/dev/null; then
    echo "✅ Server2 compose file is available"
else
    echo "❌ Server2 compose file is not available"
fi

# Test test-production.sh URL
echo "Testing production test script:"
echo "  $RELEASE_URL/test-production.sh"
if curl -I -s -f "$RELEASE_URL/test-production.sh" &>/dev/null; then
    echo "✅ Production test script is available"
else
    echo "❌ Production test script is not available"
fi

# Test README.md URL
echo "Testing deployment README:"
echo "  $RELEASE_URL/README.md"
if curl -I -s -f "$RELEASE_URL/README.md" &>/dev/null; then
    echo "✅ Deployment README is available"
else
    echo "❌ Deployment README is not available"
fi

echo ""
echo "=== Local Docker Deployment Test ==="
echo ""

# Create temporary test directory
TEST_DIR=$(mktemp -d)
cd $TEST_DIR

echo "Created test directory: $TEST_DIR"
echo ""

# Test server1 deployment
echo "Testing server1 deployment..."
cat > docker-compose.server1.yml << EOF
version: '3.8'

services:
  vpn-server1:
    image: $DOCKER_REPO:server1-latest
    container_name: vpn-server1-test
    restart: unless-stopped
    ports:
      - "9443:443"
    environment:
      - LOG_LEVEL=info
      - VMESS_UUID=550e8400-e29b-41d4-a716-446655440000
    volumes:
      - vpn-server1-logs:/var/log/xray
    networks:
      - vpn-test-network
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "443"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  vpn-server1-logs:
    driver: local

networks:
  vpn-test-network:
    driver: bridge
EOF

# Start server1
echo "Starting server1 container..."
docker-compose -f docker-compose.server1.yml up -d

# Wait for server1 to be ready
echo "Waiting for server1 to be ready..."
sleep 10

# Check if server1 is running
if docker ps | grep -q vpn-server1-test; then
    echo "✅ Server1 container is running"
    
    # Test VMess port
    if nc -zv localhost 9443 2>/dev/null; then
        echo "✅ Server1 VMess port 9443 is accessible"
    else
        echo "❌ Server1 VMess port 9443 is not accessible"
    fi
else
    echo "❌ Server1 container failed to start"
    docker logs vpn-server1-test
fi

# Test server2 deployment
echo ""
echo "Testing server2 deployment..."
cat > docker-compose.server2.yml << EOF
version: '3.8'

services:
  vpn-server2:
    image: $DOCKER_REPO:server2-latest
    container_name: vpn-server2-test
    restart: unless-stopped
    ports:
      - "9128:3128"
    environment:
      - LOG_LEVEL=info
      - VMESS_UUID=550e8400-e29b-41d4-a716-446655440000
      - SERVER1_HOST=vpn-server1-test
      - SERVER1_PORT=443
    volumes:
      - vpn-server2-logs:/var/log/xray
    networks:
      - vpn-test-network
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "3128"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  vpn-server2-logs:
    driver: local

networks:
  vpn-test-network:
    external: true
EOF

# Start server2
echo "Starting server2 container..."
docker-compose -f docker-compose.server2.yml up -d

# Wait for server2 to be ready
echo "Waiting for server2 to be ready..."
sleep 10

# Check if server2 is running
if docker ps | grep -q vpn-server2-test; then
    echo "✅ Server2 container is running"
    
    # Test HTTP proxy port
    if nc -zv localhost 9128 2>/dev/null; then
        echo "✅ Server2 HTTP proxy port 9128 is accessible"
    else
        echo "❌ Server2 HTTP proxy port 9128 is not accessible"
    fi
else
    echo "❌ Server2 container failed to start"
    docker logs vpn-server2-test
fi

echo ""
echo "Testing VMess chain functionality..."

# Test the VMess chain
RESULT=$(curl -s --max-time 10 --proxy localhost:9128 https://httpbin.org/ip 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
    echo "✅ VMess chain test successful"
    echo "Response: $RESULT"
    
    # Extract IP from response
    PROXY_IP=$(echo "$RESULT" | grep -o '"origin":[^,]*' | cut -d'"' -f4)
    echo "Proxy IP: $PROXY_IP"
else
    echo "❌ VMess chain test failed"
    echo "Checking container logs..."
    echo ""
    echo "=== Server1 Logs ==="
    docker logs vpn-server1-test | tail -10
    echo ""
    echo "=== Server2 Logs ==="
    docker logs vpn-server2-test | tail -10
fi

echo ""
echo "Cleaning up test containers..."

# Stop and remove containers
docker-compose -f docker-compose.server2.yml down -v
docker-compose -f docker-compose.server1.yml down -v

# Remove test directory
cd /
rm -rf $TEST_DIR

echo "✅ Cleanup completed"
echo ""

echo "=== Production Deployment Commands ==="
echo ""

cat << 'EOF'
# Server1 Deployment
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml
docker-compose -f docker-compose.server1.yml up -d

# Server2 Deployment
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml
sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml
docker-compose -f docker-compose.server2.yml up -d

# Test Production Setup
wget https://github.com/m3di/ai_vpn/releases/latest/download/test-production.sh
chmod +x test-production.sh
./test-production.sh SERVER2_IP SERVER1_IP
EOF

echo ""
echo "🐳 Docker Images:"
echo "  - $DOCKER_REPO:server1-latest"
echo "  - $DOCKER_REPO:server2-latest"
echo "  - $DOCKER_REPO:internet-latest"
echo "  - $DOCKER_REPO:client-latest"
echo ""
echo "Note: Deployment files will be active after creating your first release with:"
echo "  ./create-release.sh" 