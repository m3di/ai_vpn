#!/bin/bash

echo "=== VPN Experiment Test Script ==="
echo ""

# Test 1: Direct access (client -> internet)
echo "Test 1: Direct access (client -> internet)"
echo "Expected: Client IP should be visible"
echo "Command: docker exec vpn-client curl -s http://internet-server:80/"
echo ""

# Test 2: Server1 as proxy (client -> server1 -> internet)
echo "Test 2: Server1 as proxy (client -> server1 -> internet)"
echo "Expected: Server1 IP should be visible"
echo "Command: docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/"
echo ""

# Test 3: Server2 as proxy (client -> server2 -> server1 -> internet)
echo "Test 3: Server2 as proxy (client -> server2 -> server1 -> internet)"
echo "Expected: Server1 IP should be visible (server2 forwards to server1)"
echo "Command: docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/"
echo ""

echo "To run these tests after starting containers, use:"
echo "1. docker-compose up -d"
echo "2. Then execute each test command above"
echo ""

# Function to run actual tests
run_tests() {
    echo "Running actual tests..."
    
    echo "Test 1: Direct access"
    docker exec vpn-client curl -s http://internet-server:80/
    echo ""
    
    echo "Test 2: Via server1 proxy"
    docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/
    echo ""
    
    echo "Test 3: Via server2 proxy"
    docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/
    echo ""
}

# Run tests if argument is provided
if [ "$1" == "run" ]; then
    run_tests
fi 