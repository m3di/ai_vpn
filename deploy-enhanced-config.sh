#!/bin/bash

echo "=== Deploying Enhanced Anti-Censorship Configuration ==="
echo "This script will deploy VMess with TLS obfuscation and HTTP header masquerading"
echo "to help bypass SSL connection timeout issues caused by network censorship."
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    if [[ $status == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
    elif [[ $status == "FAIL" ]]; then
        echo -e "${RED}[FAIL]${NC} $message"
    elif [[ $status == "INFO" ]]; then
        echo -e "${BLUE}[INFO]${NC} $message"
    elif [[ $status == "WARN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    fi
}

# Function to backup current configurations
backup_configs() {
    print_status "INFO" "Backing up current configurations..."
    
    if [ -f "server1/xray-config.json" ]; then
        cp server1/xray-config.json server1/xray-config-backup.json
        print_status "PASS" "Server1 config backed up"
    fi
    
    if [ -f "server2/xray-config.json" ]; then
        cp server2/xray-config.json server2/xray-config-backup.json
        print_status "PASS" "Server2 config backed up"
    fi
}

# Function to deploy enhanced configurations
deploy_enhanced_configs() {
    print_status "INFO" "Deploying enhanced configurations..."
    
    # Copy enhanced configurations
    if [ -f "server1/xray-config-enhanced.json" ]; then
        cp server1/xray-config-enhanced.json server1/xray-config.json
        print_status "PASS" "Server1 enhanced config deployed"
    else
        print_status "FAIL" "Server1 enhanced config not found"
        exit 1
    fi
    
    if [ -f "server2/xray-config-enhanced.json" ]; then
        cp server2/xray-config-enhanced.json server2/xray-config.json
        print_status "PASS" "Server2 enhanced config deployed"
    else
        print_status "FAIL" "Server2 enhanced config not found"
        exit 1
    fi
}

# Function to generate certificates for server1
generate_certificates() {
    print_status "INFO" "Generating TLS certificates for server1..."
    
    # Create certificates directory if it doesn't exist
    mkdir -p server1/certs
    
    # Generate self-signed certificate that mimics cloudflare.com
    openssl req -x509 -newkey rsa:4096 -keyout server1/certs/server.key -out server1/certs/server.crt -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=Cloudflare Inc/CN=cloudflare.com" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_status "PASS" "TLS certificates generated successfully"
        print_status "INFO" "Certificate subject: cloudflare.com (for mimicking legitimate traffic)"
    else
        print_status "FAIL" "Failed to generate TLS certificates"
        exit 1
    fi
}

# Function to update server1 Dockerfile
update_server1_dockerfile() {
    print_status "INFO" "Updating server1 Dockerfile for certificate support..."
    
    # Update server1 Dockerfile to copy certificates
    sed -i.bak '/COPY xray-config.json/a\
\
# Copy certificates\
COPY certs/server.crt /etc/xray/server.crt\
COPY certs/server.key /etc/xray/server.key' server1/Dockerfile
    
    if [ $? -eq 0 ]; then
        print_status "PASS" "Server1 Dockerfile updated with certificate support"
    else
        print_status "WARN" "Failed to update server1 Dockerfile - manual update may be needed"
    fi
}

# Function to test enhanced configuration
test_enhanced_config() {
    print_status "INFO" "Testing enhanced configuration..."
    
    # Test basic connectivity
    print_status "INFO" "Testing VMess with TLS obfuscation..."
    
    # Test HTTP first (should work)
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 http://internet-server:80/status >/dev/null 2>&1; then
        print_status "PASS" "HTTP via enhanced VMess working"
    else
        print_status "FAIL" "HTTP via enhanced VMess failed"
    fi
    
    # Test HTTPS (the problematic case)
    print_status "INFO" "Testing HTTPS via enhanced VMess (anti-censorship)..."
    if docker exec vpn-client curl -s -f -k -m 20 --proxy http://vpn-server2:3128 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "HTTPS via enhanced VMess working - censorship bypassed!"
    else
        print_status "WARN" "HTTPS via enhanced VMess still failing - may need additional configuration"
    fi
    
    # Test external site
    print_status "INFO" "Testing external HTTPS site..."
    if docker exec vpn-client curl -s -f -k -m 20 --proxy http://vpn-server2:3128 https://httpbin.org/ip >/dev/null 2>&1; then
        print_status "PASS" "External HTTPS site working via enhanced VMess"
    else
        print_status "WARN" "External HTTPS site still blocked - strong censorship detected"
    fi
}

# Function to show usage instructions
show_usage() {
    print_status "INFO" "Enhanced configuration deployed successfully!"
    echo ""
    echo "Key Anti-Censorship Features:"
    echo "  ✓ TLS obfuscation with legitimate-looking certificates"
    echo "  ✓ HTTP header masquerading (mimics cloudflare.com traffic)"
    echo "  ✓ Modern TLS ciphers and fingerprinting"
    echo "  ✓ Traffic pattern obfuscation"
    echo ""
    echo "Next steps:"
    echo "  1. Rebuild containers: docker-compose down && docker-compose up -d --build"
    echo "  2. Test SSL: ./test-setup.sh ssl"
    echo "  3. Test censorship: ./test-setup.sh censorship"
    echo ""
    echo "To revert to basic configuration:"
    echo "  ./deploy-enhanced-config.sh revert"
}

# Main execution
main() {
    print_status "INFO" "Starting enhanced anti-censorship configuration deployment..."
    
    # Check if running from correct directory
    if [ ! -f "docker-compose.yml" ]; then
        print_status "FAIL" "Please run this script from the project root directory"
        exit 1
    fi
    
    # Check if enhanced configs exist
    if [ ! -f "server1/xray-config-enhanced.json" ] || [ ! -f "server2/xray-config-enhanced.json" ]; then
        print_status "FAIL" "Enhanced configuration files not found"
        print_status "INFO" "Please ensure server1/xray-config-enhanced.json and server2/xray-config-enhanced.json exist"
        exit 1
    fi
    
    # Execute deployment steps
    backup_configs
    generate_certificates
    deploy_enhanced_configs
    update_server1_dockerfile
    
    show_usage
}

# Show help
show_help() {
    echo "Enhanced Anti-Censorship Configuration Deployment"
    echo ""
    echo "This script deploys VMess with TLS obfuscation and HTTP header masquerading"
    echo "to help bypass SSL connection timeout issues caused by network censorship."
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  deploy    Deploy enhanced configuration (default)"
    echo "  test      Test current configuration"
    echo "  revert    Revert to basic configuration"
    echo "  help      Show this help message"
}

# Parse command line arguments
case "$1" in
    "deploy"|"")
        main
        ;;
    "test")
        test_enhanced_config
        ;;
    "revert")
        if [ -f "server1/xray-config-backup.json" ]; then
            cp server1/xray-config-backup.json server1/xray-config.json
            print_status "PASS" "Server1 configuration reverted"
        fi
        if [ -f "server2/xray-config-backup.json" ]; then
            cp server2/xray-config-backup.json server2/xray-config.json
            print_status "PASS" "Server2 configuration reverted"
        fi
        if [ -f "server1/Dockerfile.bak" ]; then
            mv server1/Dockerfile.bak server1/Dockerfile
            print_status "PASS" "Server1 Dockerfile reverted"
        fi
        docker-compose down && docker-compose up -d
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
