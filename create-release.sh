#!/bin/bash

# Script to create a new release for the VPN project with Docker images

set -e

echo "=== VPN Server Docker Release Creator ==="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ This is not a git repository"
    exit 1
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

# Check for Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed or not in PATH"
    exit 1
fi

# Check if logged into Docker Hub
if ! docker info | grep -q "Username"; then
    echo "❌ Not logged into Docker Hub. Please run: docker login"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️  You have uncommitted changes. Please commit them first."
    echo ""
    echo "Uncommitted files:"
    git status --porcelain
    echo ""
    read -p "Do you want to commit them now? (y/N): " COMMIT_NOW
    if [[ $COMMIT_NOW =~ ^[Yy]$ ]]; then
        echo "Staging all changes..."
        git add .
        read -p "Enter commit message: " COMMIT_MSG
        git commit -m "$COMMIT_MSG"
        echo "✅ Changes committed"
    else
        echo "❌ Please commit your changes first"
        exit 1
    fi
fi

# Get the current version
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Current version: $CURRENT_VERSION"

# Suggest next version
if [[ $CURRENT_VERSION =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
    
    NEXT_PATCH="v$MAJOR.$MINOR.$((PATCH + 1))"
    NEXT_MINOR="v$MAJOR.$((MINOR + 1)).0"
    NEXT_MAJOR="v$((MAJOR + 1)).0.0"
    
    echo ""
    echo "Suggested versions:"
    echo "  1. $NEXT_PATCH (patch)"
    echo "  2. $NEXT_MINOR (minor)"
    echo "  3. $NEXT_MAJOR (major)"
    echo "  4. Custom version"
    echo ""
    
    read -p "Choose an option (1-4): " OPTION
    
    case $OPTION in
        1) NEW_VERSION=$NEXT_PATCH ;;
        2) NEW_VERSION=$NEXT_MINOR ;;
        3) NEW_VERSION=$NEXT_MAJOR ;;
        4) 
            read -p "Enter custom version (e.g., v1.2.3): " NEW_VERSION
            if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "❌ Invalid version format. Use vX.Y.Z format"
                exit 1
            fi
            ;;
        *)
            echo "❌ Invalid option"
            exit 1
            ;;
    esac
else
    echo ""
    read -p "Enter new version (e.g., v1.0.0): " NEW_VERSION
    if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Invalid version format. Use vX.Y.Z format"
        exit 1
    fi
fi

echo ""
echo "Creating Docker release: $NEW_VERSION"
echo ""

# Check if tag already exists
if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    echo "❌ Tag $NEW_VERSION already exists"
    exit 1
fi

# Set Docker image repository
DOCKER_REPO="m3di/ai-vpn"
VERSION_TAG="${NEW_VERSION#v}"  # Remove 'v' prefix for Docker tags

echo "🐳 Building Docker images..."
echo ""

# Build server1 image
echo "Building server1 image..."
docker build -t "${DOCKER_REPO}:server1-${VERSION_TAG}" -f server1/Dockerfile server1/
docker build -t "${DOCKER_REPO}:server1-latest" -f server1/Dockerfile server1/

# Build server2 image
echo "Building server2 image..."
docker build -t "${DOCKER_REPO}:server2-${VERSION_TAG}" -f server2/Dockerfile server2/
docker build -t "${DOCKER_REPO}:server2-latest" -f server2/Dockerfile server2/

# Build internet server image
echo "Building internet server image..."
docker build -t "${DOCKER_REPO}:internet-${VERSION_TAG}" -f internet/Dockerfile internet/
docker build -t "${DOCKER_REPO}:internet-latest" -f internet/Dockerfile internet/

# Build client image
echo "Building client image..."
docker build -t "${DOCKER_REPO}:client-${VERSION_TAG}" -f client/Dockerfile client/
docker build -t "${DOCKER_REPO}:client-latest" -f client/Dockerfile client/

echo ""
echo "🚀 Pushing Docker images to Docker Hub..."
echo ""

# Push server1 images
echo "Pushing server1 images..."
docker push "${DOCKER_REPO}:server1-${VERSION_TAG}"
docker push "${DOCKER_REPO}:server1-latest"

# Push server2 images
echo "Pushing server2 images..."
docker push "${DOCKER_REPO}:server2-${VERSION_TAG}"
docker push "${DOCKER_REPO}:server2-latest"

# Push internet server images
echo "Pushing internet server images..."
docker push "${DOCKER_REPO}:internet-${VERSION_TAG}"
docker push "${DOCKER_REPO}:internet-latest"

# Push client images
echo "Pushing client images..."
docker push "${DOCKER_REPO}:client-${VERSION_TAG}"
docker push "${DOCKER_REPO}:client-latest"

echo ""
echo "📦 Creating production deployment files..."
echo ""

# Create release directory
mkdir -p release

# Create server1 docker-compose file
cat > release/docker-compose.server1.yml << EOF
version: '3.8'

services:
  vpn-server1:
    image: ${DOCKER_REPO}:server1-${VERSION_TAG}
    container_name: vpn-server1
    restart: unless-stopped
    ports:
      - "443:443"
    environment:
      - LOG_LEVEL=info
      - VMESS_UUID=550e8400-e29b-41d4-a716-446655440000
    volumes:
      - vpn-server1-logs:/var/log/xray
    networks:
      - vpn-network
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "443"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

volumes:
  vpn-server1-logs:
    driver: local

networks:
  vpn-network:
    driver: bridge
EOF

# Create server2 docker-compose file
cat > release/docker-compose.server2.yml << EOF
version: '3.8'

services:
  vpn-server2:
    image: ${DOCKER_REPO}:server2-${VERSION_TAG}
    container_name: vpn-server2
    restart: unless-stopped
    ports:
      - "3128:3128"
    environment:
      - LOG_LEVEL=info
      - VMESS_UUID=550e8400-e29b-41d4-a716-446655440000
      - SERVER1_HOST=SERVER1_IP_PLACEHOLDER
      - SERVER1_PORT=443
    volumes:
      - vpn-server2-logs:/var/log/xray
    networks:
      - vpn-network
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "3128"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

volumes:
  vpn-server2-logs:
    driver: local

networks:
  vpn-network:
    driver: bridge
EOF

# Create production test script
cat > release/test-production.sh << 'EOF'
#!/bin/bash

# Production test script for VPN Docker deployment

set -e

SERVER2_IP=${1:-"localhost"}
SERVER1_IP=${2:-""}

echo "=== VPN Production Test ==="
echo "Server2 IP: $SERVER2_IP"
echo "Server1 IP: $SERVER1_IP"
echo ""

# Test server2 HTTP proxy port
echo "Testing Server2 HTTP proxy port..."
if nc -zv $SERVER2_IP 3128 2>/dev/null; then
    echo "✅ Server2 port 3128 is accessible"
else
    echo "❌ Server2 port 3128 is not accessible"
    exit 1
fi

# Test server1 VMess port (if IP provided)
if [ -n "$SERVER1_IP" ]; then
    echo "Testing Server1 VMess port..."
    if nc -zv $SERVER1_IP 443 2>/dev/null; then
        echo "✅ Server1 port 443 is accessible"
    else
        echo "❌ Server1 port 443 is not accessible"
        exit 1
    fi
fi

# Test VMess chain
echo ""
echo "Testing VMess proxy chain..."
RESULT=$(curl -s --max-time 10 --proxy $SERVER2_IP:3128 https://httpbin.org/ip)

if [ $? -eq 0 ]; then
    echo "✅ VMess chain test successful"
    echo "Response: $RESULT"
    
    # Extract IP from response
    PROXY_IP=$(echo "$RESULT" | grep -o '"origin":[^,]*' | cut -d'"' -f4)
    echo "Proxy IP: $PROXY_IP"
else
    echo "❌ VMess chain test failed"
    exit 1
fi

# Test HTTPS
echo ""
echo "Testing HTTPS through VMess chain..."
HTTPS_RESULT=$(curl -s --max-time 10 --proxy $SERVER2_IP:3128 https://httpbin.org/user-agent)

if [ $? -eq 0 ]; then
    echo "✅ HTTPS test successful"
    echo "Response: $HTTPS_RESULT"
else
    echo "❌ HTTPS test failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! VPN is working correctly."
echo ""
echo "To use this VPN, configure your applications with:"
echo "  Proxy Type: HTTP Proxy"
echo "  Proxy Server: $SERVER2_IP"
echo "  Port: 3128"
EOF

chmod +x release/test-production.sh

# Create deployment README
cat > release/README.md << EOF
# VPN Docker Deployment - $NEW_VERSION

This release contains production-ready Docker images and deployment files for the VPN proxy chain with VMess protocol.

## Docker Images

The following images are available on Docker Hub:

- **Server1 (VMess Server)**: \`${DOCKER_REPO}:server1-${VERSION_TAG}\` or \`${DOCKER_REPO}:server1-latest\`
- **Server2 (VMess Client)**: \`${DOCKER_REPO}:server2-${VERSION_TAG}\` or \`${DOCKER_REPO}:server2-latest\`
- **Internet Server**: \`${DOCKER_REPO}:internet-${VERSION_TAG}\` or \`${DOCKER_REPO}:internet-latest\`
- **Client**: \`${DOCKER_REPO}:client-${VERSION_TAG}\` or \`${DOCKER_REPO}:client-latest\`

## Quick Deployment

### Server1 (Exit Point)

\`\`\`bash
# Download and deploy server1
wget https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server1.yml
docker-compose -f docker-compose.server1.yml up -d
\`\`\`

### Server2 (Entry Point)

\`\`\`bash
# Download and deploy server2
wget https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server2.yml

# Update SERVER1_IP
sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml

# Deploy server2
docker-compose -f docker-compose.server2.yml up -d
\`\`\`

## Testing

\`\`\`bash
# Download test script
wget https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/test-production.sh
chmod +x test-production.sh

# Run tests
./test-production.sh SERVER2_IP SERVER1_IP
\`\`\`

## Architecture

\`\`\`
Client → Server2 (HTTP:3128 → VMess) → Server1 (VMess Server:443) → Internet
\`\`\`

## Features

- **VMess Protocol**: Enhanced security with protocol obfuscation
- **Docker Deployment**: Easy deployment and scaling
- **Health Checks**: Automatic service monitoring
- **Resource Limits**: Production-ready resource management
- **Persistent Logs**: Volume-mounted logging
- **Auto-Restart**: Containers restart on failure

## Support

For issues and questions:
- Check container logs: \`docker logs <container-name>\`
- Review deployment documentation
- Create an issue on GitHub
EOF

echo ""
echo "📝 Committing changes and creating release..."
echo ""

# Push current changes
echo "Pushing changes to origin..."
git push origin main

# Create and push tag
echo "Creating tag: $NEW_VERSION"
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION - Docker images and VMess protocol"

echo "Pushing tag to origin..."
git push origin "$NEW_VERSION"

echo ""
echo "✅ Release $NEW_VERSION created successfully!"
echo ""
echo "🐳 Docker images pushed to Docker Hub:"
echo "  - ${DOCKER_REPO}:server1-${VERSION_TAG}"
echo "  - ${DOCKER_REPO}:server2-${VERSION_TAG}"
echo "  - ${DOCKER_REPO}:internet-${VERSION_TAG}"
echo "  - ${DOCKER_REPO}:client-${VERSION_TAG}"
echo ""
echo "🔄 GitHub Actions will now:"
echo "  - Create the GitHub release"
echo "  - Upload deployment files"
echo "  - Generate production documentation"
echo ""
echo "🌐 Check the release at:"
echo "  https://github.com/m3di/ai_vpn/releases/tag/$NEW_VERSION"
echo ""
echo "📥 Deployment files will be available at:"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server1.yml"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server2.yml"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/test-production.sh"
echo ""
echo "⏳ Allow 1-2 minutes for the release to be published..."

# Clean up
rm -rf release/ 