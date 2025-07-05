# VPN Proxy Chain Test Environment

## Overview
This Docker-based test environment simulates a VPN proxy chain with comprehensive testing capabilities for multiple protocols and services.

## Architecture
```
Client Container → Server2 Proxy → Server1 Proxy → Internet Server
```

### Container Roles
- **Client Container**: Test client with curl and networking tools
- **Server2 (VPN Entry Point)**: Squid proxy that forwards to Server1
- **Server1 (VPN Exit Point)**: Squid proxy that connects to Internet
- **Internet Server**: Multi-service test server with HTTP/HTTPS endpoints

## Services Available

### Internet Server Services
1. **HTTP Basic Service** (Port 80)
   - Endpoint: `http://internet-server:80/`
   - Returns JSON with client IP, protocol info, and request details

2. **HTTPS Service** (Port 443)
   - Endpoint: `https://internet-server:443/`
   - Returns JSON with TLS version info and client details
   - Uses self-signed certificate for testing

3. **Status Endpoint** (Port 80)
   - Endpoint: `http://internet-server:80/status`
   - Returns server status and available services

4. **Download Service** (Port 80)
   - Endpoint: `http://internet-server:80/download`
   - Returns a test file for download testing

5. **Upload Service** (Port 80)
   - Endpoint: `http://internet-server:80/upload`
   - Accepts POST requests for upload testing
   - Returns upload size and metadata

### External Access
- HTTP: `http://localhost:8080/`
- HTTPS: `https://localhost:8443/`

## IP Address Verification
The test environment allows you to verify the VPN proxy chain is working by observing different client IPs:

- **Direct Connection**: Shows client container IP (`172.20.0.5`)
- **Via Server1**: Shows Server1 IP (`172.20.0.3`)
- **Via Server2**: Shows Server1 IP (`172.20.0.3`) - confirms traffic goes through the full chain

## Testing

### Quick Start
```bash
# Start all containers
docker-compose up -d

# Run comprehensive tests
./test-setup.sh

# Run specific test categories
./test-setup.sh curl      # Basic HTTP/HTTPS tests
./test-setup.sh advanced  # File transfer tests
./test-setup.sh tcp       # TCP connection tests
./test-setup.sh ip        # IP address verification
./test-setup.sh performance  # Performance comparison
```

### Manual Testing Examples

#### Basic HTTP Test
```bash
# Direct connection
docker exec vpn-client curl -s http://internet-server:80/

# Via Server1 proxy
docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/

# Via Server2 proxy (full chain)
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/
```

#### HTTPS Test
```bash
# Direct HTTPS
docker exec vpn-client curl -s -k https://internet-server:443/

# HTTPS via proxy
docker exec vpn-client curl -s -k --proxy http://vpn-server2:3128 https://internet-server:443/
```

#### File Transfer Tests
```bash
# Download test
docker exec vpn-client curl -s http://internet-server:80/download | head -5

# Upload test
docker exec vpn-client curl -s -X POST -d "test data" http://internet-server:80/upload
```

#### Service Status
```bash
# Check available services
docker exec vpn-client curl -s http://internet-server:80/status
```

## Test Script Features

The `test-setup.sh` script includes:

1. **Container Status Verification**: Checks all containers are running
2. **Service Readiness**: Waits for services to be available
3. **Comprehensive Testing**: Tests multiple protocols and endpoints
4. **IP Verification**: Confirms proxy chain is working
5. **Performance Testing**: Compares response times across configurations
6. **Colored Output**: Clear pass/fail indicators
7. **Modular Testing**: Run specific test categories

## Expected Results

### Working VPN Chain Indicators
- ✅ All containers start successfully
- ✅ TCP connections work to all services
- ✅ HTTP requests succeed through all proxy configurations
- ✅ HTTPS requests work with TLS 1.3
- ✅ Different client IPs are reported based on proxy path
- ✅ File uploads/downloads work through proxies
- ✅ Response times increase slightly through proxy chain

### Troubleshooting
- If tests fail, check container logs: `docker logs <container-name>`
- Verify network connectivity: `docker exec vpn-client nc -z <host> <port>`
- Check proxy configurations in `server1/squid.conf` and `server2/squid.conf`

## Performance Characteristics
Typical response times observed:
- Direct connection: ~0.001s
- Via Server1: ~0.001s
- Via Server2 (full chain): ~0.001s

The proxy chain adds minimal latency for testing purposes.

## Security Notes
- Uses self-signed certificates for HTTPS testing
- Squid proxies configured for testing (not production security)
- All traffic is contained within Docker network

## Extending the Test Environment

To add new services:
1. Add endpoints to `internet/main.go`
2. Update test scripts to include new endpoints
3. Document new services in this file

To add new protocols:
1. Update internet server to support new protocols
2. Add client-side testing tools to `client/Dockerfile`
3. Create corresponding test functions in `test-setup.sh` 