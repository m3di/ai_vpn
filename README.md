# VPN Experiment with Docker Containers

This project demonstrates a VPN-like setup using 4 Docker containers representing real-world computers in multiple locations.

## Architecture

```
Client → Server2 (Entry Point) → Server1 (Exit Point) → Internet Server
```

## Containers

1. **`internet`** - A Go web application that returns the client's IP address
2. **`server1`** - VPN exit point using Squid proxy
3. **`server2`** - VPN entry point using Squid proxy (forwards to server1)
4. **`client`** - Represents the client wanting to browse the internet

## Network Behavior

- **Direct access**: `client → internet` → Returns client IP (172.20.0.5)
- **Via server1**: `client → server1 → internet` → Returns server1 IP (172.20.0.3)
- **Via server2**: `client → server2 → server1 → internet` → Returns server1 IP (172.20.0.3)

## Quick Start

1. **Build and start all containers:**
   ```bash
   docker-compose up -d
   ```

2. **Run the test script:**
   ```bash
   ./test-setup.sh run
   ```

## Manual Testing

```bash
# Test 1: Direct access
docker exec vpn-client curl -s http://internet-server:80/

# Test 2: Via server1 proxy
docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/

# Test 3: Via server2 proxy
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/
```

## Expected Results

- **Direct access**: Shows client IP (172.20.0.5)
- **Server1 proxy**: Shows server1 IP (172.20.0.3)
- **Server2 proxy**: Shows server1 IP (172.20.0.3) because server2 forwards to server1

## Container Details

### Internet Server
- **Language**: Go
- **Port**: 80
- **Function**: Returns client IP information in JSON format
- **External access**: Available on localhost:8080

### Server1 (VPN Exit Point)
- **Proxy**: Squid on port 3128
- **Function**: Acts as the final proxy before reaching the internet
- **Configuration**: Allows all traffic, forwards client information

### Server2 (VPN Entry Point)
- **Proxy**: Squid on port 3128
- **Function**: Forwards all traffic to server1
- **Configuration**: Uses server1 as parent proxy

### Client
- **Base**: Alpine Linux
- **Tools**: curl, wget, netcat
- **Function**: Simulates a user wanting to browse the internet

## Network Configuration

- **Subnet**: 172.20.0.0/16
- **Internet Server**: 172.20.0.2
- **Server1**: 172.20.0.3
- **Server2**: 172.20.0.4
- **Client**: 172.20.0.5

## Files Structure

```
docker-vpn/
├── docker-compose.yml          # Main orchestration file
├── internet/
│   ├── Dockerfile
│   └── main.go                 # Go web server
├── server1/
│   ├── Dockerfile
│   └── squid.conf              # Squid configuration
├── server2/
│   ├── Dockerfile
│   └── squid.conf              # Squid configuration
├── client/
│   └── Dockerfile
├── test-setup.sh               # Test script
└── README.md                   # This file
```

## Security & Performance Notes

- Traffic is routed through multiple proxies to simulate real-world VPN behavior
- Squid proxy is configured for optimal performance
- All containers run in an isolated Docker network
- No caching is enabled for testing purposes

## Stopping the Experiment

```bash
docker-compose down
```

## Troubleshooting

- **Check container status**: `docker-compose ps`
- **View logs**: `docker logs <container-name>`
- **Access container shell**: `docker exec -it <container-name> sh` 