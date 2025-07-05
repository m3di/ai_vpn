# VPN Proxy Chain Test Environment (with VMess Protocol)

## Overview
This Docker-based test environment simulates a VPN proxy chain with VMess protocol support and comprehensive testing capabilities for multiple protocols and services.

## Architecture
```
Client Container → Server2 (HTTP→VMess) → Server1 (VMess Server) → Internet Server
```

### Container Roles
- **Client Container**: Test client with curl and networking tools
- **Server2 (VPN Entry Point)**: Xray proxy accepting HTTP proxy connections, forwarding via VMess to Server1
- **Server1 (VPN Exit Point)**: Xray VMess server that connects to Internet
- **Internet Server**: Multi-service test server with HTTP/HTTPS endpoints

### Protocol Chain
1. **Client → Server2**: HTTP proxy protocol (port 3128)
2. **Server2 → Server1**: VMess protocol (port 443)
3. **Server1 → Internet**: Direct connection (freedom outbound)

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

### VMess Configuration
- **Protocol**: VMess (V2Ray/Xray)
- **UUID**: `550e8400-e29b-41d4-a716-446655440000`
- **Port**: 443 (Server1)
- **Security**: Auto
- **Transport**: TCP (no encryption for testing)

### External Access
- HTTP: `http://localhost:8080/`
- HTTPS: `https://localhost:8443/`

## IP Address Verification
The test environment allows you to verify the VMess proxy chain is working by observing different client IPs:

- **Direct Connection**: Shows client container IP (`172.20.0.5`)
- **Via Server2 (VMess Chain)**: Shows Server1 IP (`172.20.0.3`) - confirms traffic goes through the full VMess chain

## Testing

### Quick Start
```bash
# Start all containers
docker-compose up -d

# Run comprehensive tests (including VMess)
./test-setup.sh

# Run specific test categories
./test-setup.sh curl      # Basic HTTP/HTTPS tests
./test-setup.sh advanced  # File transfer tests via VMess
./test-setup.sh tcp       # TCP connection tests
./test-setup.sh vmess     # VMess protocol specific tests
./test-setup.sh ip        # IP address verification
./test-setup.sh performance  # Performance comparison
```

### VMess-Specific Testing
```bash
# Test VMess protocol chain
./test-setup.sh vmess

# Check VMess connectivity
docker exec vpn-server2 nc -z vpn-server1 443

# View VMess server logs
docker logs vpn-server1
docker logs vpn-server2
```

### Manual Testing Examples

#### Basic HTTP Test (VMess Chain)
```bash
# Direct connection
docker exec vpn-client curl -s http://internet-server:80/

# Via Server2 (VMess chain) - this is now the only proxy option
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/

# Note: Server1 no longer accepts HTTP proxy connections (only VMess)
```

#### HTTPS Test (VMess Chain)
```bash
# Direct HTTPS
docker exec vpn-client curl -s -k https://internet-server:443/

# HTTPS via VMess chain
docker exec vpn-client curl -s -k --proxy http://vpn-server2:3128 https://internet-server:443/
```

#### File Transfer Tests (VMess Chain)
```bash
# Download test via VMess
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/download | head -5

# Upload test via VMess
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 -X POST -d "test data" http://internet-server:80/upload
```

## Test Script Features

The `test-setup.sh` script includes:

1. **Container Status Verification**: Checks all containers are running
2. **Service Readiness**: Waits for services to be available
3. **VMess Protocol Testing**: Specific tests for VMess connectivity
4. **Comprehensive Testing**: Tests multiple protocols and endpoints via VMess
5. **IP Verification**: Confirms VMess proxy chain is working
6. **Performance Testing**: Compares response times across configurations
7. **Colored Output**: Clear pass/fail indicators
8. **Modular Testing**: Run specific test categories including VMess tests

## Expected Results

### Working VMess Chain Indicators
- ✅ All containers start successfully with Xray
- ✅ VMess port 443 accessible from server2 to server1
- ✅ HTTP proxy port 3128 accessible from client to server2
- ✅ HTTP requests succeed through VMess chain
- ✅ HTTPS requests work with TLS 1.3 through VMess
- ✅ Different client IPs are reported (proving VMess chain works)
- ✅ File uploads/downloads work through VMess chain
- ✅ Server1 correctly rejects direct HTTP proxy connections

### VMess Protocol Verification
- ✅ Server1 logs show VMess server starting
- ✅ Server2 logs show VMess client connections
- ✅ Traffic flows: Client → HTTP Proxy → VMess → Internet
- ✅ IP masking works correctly through VMess

### Troubleshooting
- Check Xray logs: `docker logs vpn-server1` and `docker logs vpn-server2`
- Verify VMess connectivity: `docker exec vpn-server2 nc -z vpn-server1 443`
- Check VMess UUID matches in both configurations
- Verify network connectivity: `docker exec vpn-client nc -z <host> <port>`

## Performance Characteristics
Typical response times observed:
- Direct connection: ~0.001s
- Via VMess chain: ~0.002-0.005s

The VMess protocol adds minimal latency but provides enhanced security and protocol obfuscation.

## Security Features

### VMess Protocol Benefits
- **Protocol Obfuscation**: VMess traffic is harder to detect than HTTP proxy
- **UUID Authentication**: Secure client authentication
- **Dynamic Port Support**: Can be configured on any port
- **Advanced Routing**: Sophisticated traffic routing capabilities

### Configuration Security
- VMess UUID: `550e8400-e29b-41d4-a716-446655440000` (change for production)
- No TLS encryption in test environment (add `"security": "tls"` for production)
- Blackhole routing for private IP ranges

## Extending the Test Environment

### Adding New VMess Features
1. Enable TLS encryption in VMess streamSettings
2. Add WebSocket transport for better firewall traversal
3. Implement traffic obfuscation with different headers
4. Add multiple VMess users with different UUIDs

### Adding New Protocols
1. Configure additional inbound protocols in Xray
2. Add protocol-specific testing in test-setup.sh
3. Update documentation for new protocol chains

### Configuration Files
- **Server1**: `server1/xray-config.json` (VMess server)
- **Server2**: `server2/xray-config.json` (HTTP proxy + VMess client)
- **Test Script**: `test-setup.sh` (includes VMess tests)

## VMess vs HTTP Proxy Comparison

| Feature | HTTP Proxy | VMess |
|---------|------------|-------|
| Detection Resistance | Low | High |
| Protocol Overhead | Minimal | Low |
| Configuration Complexity | Simple | Moderate |
| Security | Basic | Advanced |
| Firewall Traversal | Limited | Good |
| Performance | Fastest | Fast |

The VMess implementation provides a more realistic VPN scenario with enhanced security and protocol obfuscation capabilities. 