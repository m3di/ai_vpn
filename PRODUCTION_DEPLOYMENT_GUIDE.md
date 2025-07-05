# Production Deployment Guide - Enhanced Anti-Censorship Edition

## Overview

This guide covers deploying the enhanced anti-censorship VPN solution to production servers. The new release includes:

- **TLS Obfuscation**: VMess traffic encrypted with TLS
- **HTTP Header Masquerading**: Traffic mimics cloudflare.com
- **Certificate Spoofing**: Legitimate-looking certificates
- **DPI Resistance**: Bypasses SSL connection timeout issues

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Servers with ports 443 (Server1) and 3128 (Server2) available
- Network connectivity between servers

## 🚀 New Deployment (Fresh Installation)

### Server1 (Exit Point) - Enhanced VMess Server

```bash
# Download enhanced configuration
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml

# Deploy with anti-censorship features
docker-compose -f docker-compose.server1.yml up -d

# Verify anti-censorship features are enabled
docker logs vpn-server1 | grep "Anti-Censorship Features"
```

Expected output should show:
```
✓ TLS Obfuscation: Enabled
✓ HTTP Header Masquerading: Enabled
✓ Certificate Spoofing: cloudflare.com
✓ Traffic Pattern Obfuscation: Enabled
✓ Port 443 (HTTPS): Standard port for evasion
```

### Server2 (Entry Point) - Enhanced VMess Client

```bash
# Download enhanced configuration
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml

# Update server1 IP address
sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml

# Deploy enhanced server2
docker-compose -f docker-compose.server2.yml up -d

# Verify connection to server1
docker logs vpn-server2 | grep "VMess Outbound to Server1"
```

## 🔄 Updating Existing Production Deployment

### Step 1: Backup Current Configuration

```bash
# On Server1
docker-compose down
docker commit vpn-server1 vpn-server1-backup:$(date +%Y%m%d)

# On Server2  
docker-compose down
docker commit vpn-server2 vpn-server2-backup:$(date +%Y%m%d)
```

### Step 2: Update to Enhanced Anti-Censorship Release

```bash
# Download latest release files
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml

# On Server1 - Deploy enhanced version
docker-compose -f docker-compose.server1.yml pull
docker-compose -f docker-compose.server1.yml up -d

# On Server2 - Update IP and deploy
sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml
docker-compose -f docker-compose.server2.yml pull  
docker-compose -f docker-compose.server2.yml up -d
```

### Step 3: Verify Anti-Censorship Features

```bash
# Check Server1 anti-censorship features
docker logs vpn-server1 | grep -A 10 "Anti-Censorship Features"

# Check Server2 VMess connection
docker logs vpn-server2 | grep "VMess"

# Test the enhanced proxy chain
curl --proxy YOUR_SERVER2_IP:3128 https://httpbin.org/ip
```

## 🧪 Testing Anti-Censorship Solution

### Download Production Test Script

```bash
wget https://github.com/m3di/ai_vpn/releases/latest/download/test-production.sh
chmod +x test-production.sh
```

### Run Comprehensive Tests

```bash
# Basic functionality test
./test-production.sh YOUR_SERVER2_IP YOUR_SERVER1_IP

# Test SSL timeout resistance
curl -v --max-time 20 --proxy YOUR_SERVER2_IP:3128 https://httpbin.org/ip

# Test HTTPS sites that commonly experience timeouts
curl --proxy YOUR_SERVER2_IP:3128 https://www.google.com
curl --proxy YOUR_SERVER2_IP:3128 https://www.facebook.com
```

### Expected Results

- ✅ **HTTP requests**: Should work through proxy
- ✅ **HTTPS requests**: Should work without SSL timeouts
- ✅ **External sites**: Should be accessible through enhanced VMess
- ✅ **No DPI detection**: Traffic should appear as legitimate HTTPS

## 📊 Monitoring and Troubleshooting

### Check Container Status

```bash
# Server1 status
docker ps | grep vpn-server1
docker logs vpn-server1 --tail 50

# Server2 status  
docker ps | grep vpn-server2
docker logs vpn-server2 --tail 50
```

### Verify TLS Configuration

```bash
# Check TLS certificates on Server1
docker exec vpn-server1 openssl x509 -in /etc/xray/server.crt -noout -text | grep "Subject:"

# Test TLS handshake
docker exec vpn-server2 openssl s_client -connect vpn-server1:443 -servername cloudflare.com
```

### Performance Monitoring

```bash
# Check response times
time curl --proxy YOUR_SERVER2_IP:3128 https://httpbin.org/ip

# Monitor resource usage
docker stats vpn-server1 vpn-server2
```

## 🔧 Configuration Customization

### Change VMess UUID (Recommended for Production)

1. **Generate new UUID:**
   ```bash
   # Generate new UUID
   uuidgen
   ```

2. **Update configurations:**
   - Edit both server1 and server2 docker-compose files
   - Update `VMESS_UUID` environment variable
   - Restart containers

### Customize TLS Certificate

1. **Generate custom certificate:**
   ```bash
   openssl req -x509 -newkey rsa:4096 \
     -keyout server.key -out server.crt \
     -days 365 -nodes \
     -subj "/C=US/ST=CA/L=Your City/O=Your Org/CN=your-domain.com"
   ```

2. **Update Server1 container:**
   ```bash
   docker cp server.crt vpn-server1:/etc/xray/server.crt
   docker cp server.key vpn-server1:/etc/xray/server.key
   docker restart vpn-server1
   ```

## 🛡️ Security Recommendations

### Production Security Checklist

- [ ] **Change default UUID** from `550e8400-e29b-41d4-a716-446655440000`
- [ ] **Use custom TLS certificates** instead of auto-generated ones
- [ ] **Configure firewall rules** to allow only necessary ports
- [ ] **Enable log rotation** to prevent disk space issues
- [ ] **Regular security updates** for Docker images
- [ ] **Monitor access logs** for suspicious activity
- [ ] **Use strong server passwords** and SSH key authentication

### Firewall Configuration

```bash
# Server1 (VMess Server)
ufw allow 443/tcp
ufw deny 3128/tcp  # Server1 no longer needs HTTP proxy port

# Server2 (VMess Client/HTTP Proxy)  
ufw allow 3128/tcp
ufw allow from SERVER1_IP to any port 443  # Allow connection to Server1
```

## 📈 Performance Optimization

### Resource Limits

The enhanced configuration includes optimized resource limits:

```yaml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M
```

### Connection Optimization

- **TCP Fast Open**: Enabled for faster connections
- **Keep-Alive**: Optimized for persistent connections  
- **Buffer Sizes**: Tuned for better throughput

## 🆘 Rollback Procedure

If issues occur with the enhanced version:

```bash
# Stop enhanced containers
docker-compose down

# Restore from backup
docker tag vpn-server1-backup:YYYYMMDD vpn-server1:latest
docker tag vpn-server2-backup:YYYYMMDD vpn-server2:latest

# Restart with previous version
docker-compose up -d
```

## 🔍 Logs and Debugging

### Enhanced Logging Features

The new release includes comprehensive logging:

1. **V2Ray Client Configuration**: Displayed on container start
2. **Anti-Censorship Status**: Shows enabled features
3. **TLS Certificate Info**: Certificate subject and expiry
4. **Connection Details**: VMess UUID, ports, security settings

### Access Logs

```bash
# View detailed access logs
docker exec vpn-server1 tail -f /var/log/xray/access.log
docker exec vpn-server2 tail -f /var/log/xray/access.log

# Filter for specific patterns
docker logs vpn-server1 | grep "TLS"
docker logs vpn-server2 | grep "VMess"
```

## 📞 Support and Updates

### Checking for Updates

```bash
# Check current version
docker images | grep m3di/ai-vpn

# Pull latest version
docker-compose pull
docker-compose up -d
```

## 🎯 Success Indicators

Your enhanced anti-censorship VPN is working correctly when:

- ✅ Server1 logs show "✓ TLS Obfuscation: Enabled"
- ✅ HTTPS requests work without SSL timeouts
- ✅ External sites accessible through proxy
- ✅ Response times are reasonable (<5 seconds for external sites)
- ✅ No connection refused errors
- ✅ Traffic analysis shows HTTPS-like patterns

## 📊 Performance Benchmarks

Expected performance with enhanced anti-censorship:

- **HTTP requests**: ~100-200ms overhead
- **HTTPS requests**: ~200-500ms overhead (due to double TLS)
- **Large file downloads**: ~5-10% bandwidth overhead
- **Connection establishment**: ~1-2 seconds for first connection

The enhanced anti-censorship features provide significant improvements in bypassing network restrictions while maintaining excellent performance for most use cases.
