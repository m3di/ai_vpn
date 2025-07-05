#!/bin/bash

echo "=== VPN Proxy Chain Comprehensive Test Suite ==="
echo "This script tests HTTP, HTTPS, file transfers, and TCP connections"
echo "through various proxy configurations including VMess protocol."
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if container is running
check_container() {
    local container_name=$1
    if docker ps --format 'table {{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local timeout=30
    local count=0
    
    print_status "INFO" "Waiting for $service_name to be ready..."
    
    while [ $count -lt $timeout ]; do
        if docker exec vpn-client nc -z $host $port 2>/dev/null; then
            print_status "PASS" "$service_name is ready"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    print_status "FAIL" "$service_name failed to start within ${timeout}s"
    return 1
}

# Function to check VMess connectivity
check_vmess_connectivity() {
    echo ""
    echo "=== VMess Protocol Tests ==="
    
    print_status "INFO" "Checking VMess server (server1) logs..."
    docker logs vpn-server1 --tail 10 2>/dev/null | grep -i "vmess\|xray\|listening\|started" | head -3
    
    print_status "INFO" "Checking VMess client (server2) logs..."
    docker logs vpn-server2 --tail 10 2>/dev/null | grep -i "vmess\|xray\|listening\|started" | head -3
    
    print_status "INFO" "Testing VMess connection chain..."
    
    # Test if server1 VMess port is accessible from server2
    if docker exec vpn-server2 nc -z vpn-server1 443 2>/dev/null; then
        print_status "PASS" "VMess port 443 accessible from server2"
    else
        print_status "FAIL" "VMess port 443 NOT accessible from server2"
    fi
    
    # Test if server2 HTTP proxy port is accessible from client
    if docker exec vpn-client nc -z vpn-server2 3128 2>/dev/null; then
        print_status "PASS" "HTTP proxy port 3128 accessible from client"
    else
        print_status "FAIL" "HTTP proxy port 3128 NOT accessible from client"
    fi
    
    # Test the full VMess chain with a simple HTTP request
    print_status "INFO" "Testing full VMess chain (Client → Server2 HTTP → Server1 VMess → Internet)..."
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 http://internet-server:80/status >/dev/null 2>&1; then
        print_status "PASS" "Full VMess proxy chain working"
    else
        print_status "FAIL" "Full VMess proxy chain failed"
    fi
}

# Function to run basic curl tests
run_curl_tests() {
    echo ""
    echo "=== Basic cURL Tests ==="
    
    # Test 1: Direct HTTP
    print_status "INFO" "Testing direct HTTP connection..."
    if docker exec vpn-client curl -s -f -m 10 http://internet-server:80/ >/dev/null 2>&1; then
        print_status "PASS" "Direct HTTP connection"
    else
        print_status "FAIL" "Direct HTTP connection"
    fi
    
    # Test 2: HTTP via server1 (now VMess) - this should fail as server1 no longer accepts HTTP proxy
    print_status "INFO" "Testing HTTP via server1 (VMess - should fail)..."
    if docker exec vpn-client curl -s -f -m 10 --proxy http://vpn-server1:3128 http://internet-server:80/ >/dev/null 2>&1; then
        print_status "WARN" "HTTP via server1 unexpectedly succeeded (VMess server should not accept HTTP proxy)"
    else
        print_status "PASS" "HTTP via server1 correctly failed (VMess server doesn't accept HTTP proxy)"
    fi
    
    # Test 3: HTTP via server2 (full VMess chain)
    print_status "INFO" "Testing HTTP via server2 (VMess chain)..."
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 http://internet-server:80/ >/dev/null 2>&1; then
        print_status "PASS" "HTTP via server2 (VMess chain)"
    else
        print_status "FAIL" "HTTP via server2 (VMess chain)"
    fi
    
    # Test 4: HTTPS tests
    print_status "INFO" "Testing HTTPS connections..."
    
    # Direct HTTPS
    if docker exec vpn-client curl -s -f -k -m 10 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "Direct HTTPS connection"
    else
        print_status "FAIL" "Direct HTTPS connection"
    fi
    
    # HTTPS via server2 (VMess chain)
    if docker exec vpn-client curl -s -f -k -m 15 --proxy http://vpn-server2:3128 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "HTTPS via server2 (VMess chain)"
    else
        print_status "FAIL" "HTTPS via server2 (VMess chain)"
    fi
}

# Function to run advanced tests
run_advanced_tests() {
    echo ""
    echo "=== Advanced Protocol Tests ==="
    
    # Test file download via VMess chain
    print_status "INFO" "Testing file download via VMess chain..."
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 http://internet-server:80/download -o /tmp/test_download.txt >/dev/null 2>&1; then
        print_status "PASS" "File download via VMess chain"
    else
        print_status "FAIL" "File download via VMess chain"
    fi
    
    # Test file upload via VMess chain
    print_status "INFO" "Testing file upload via VMess chain..."
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 -X POST -d "test upload data via VMess" http://internet-server:80/upload >/dev/null 2>&1; then
        print_status "PASS" "File upload via VMess chain"
    else
        print_status "FAIL" "File upload via VMess chain"
    fi
    
    # Test status endpoint via VMess chain
    print_status "INFO" "Testing status endpoint via VMess chain..."
    if docker exec vpn-client curl -s -f -m 15 --proxy http://vpn-server2:3128 http://internet-server:80/status >/dev/null 2>&1; then
        print_status "PASS" "Status endpoint via VMess chain"
    else
        print_status "FAIL" "Status endpoint via VMess chain"
    fi
}

# Function to run TCP connection tests
run_tcp_tests() {
    echo ""
    echo "=== TCP Connection Tests ==="
    
    # Test TCP connections
    print_status "INFO" "Testing TCP connections..."
    
    # Direct TCP to HTTP port
    if docker exec vpn-client nc -z internet-server 80 2>/dev/null; then
        print_status "PASS" "Direct TCP connection to HTTP port"
    else
        print_status "FAIL" "Direct TCP connection to HTTP port"
    fi
    
    # Direct TCP to HTTPS port
    if docker exec vpn-client nc -z internet-server 443 2>/dev/null; then
        print_status "PASS" "Direct TCP connection to HTTPS port"
    else
        print_status "FAIL" "Direct TCP connection to HTTPS port"
    fi
    
    # TCP to server1 VMess port
    if docker exec vpn-client nc -z vpn-server1 443 2>/dev/null; then
        print_status "PASS" "TCP connection to server1 VMess port (443)"
    else
        print_status "FAIL" "TCP connection to server1 VMess port (443)"
    fi
    
    # TCP to server2 HTTP proxy port
    if docker exec vpn-client nc -z vpn-server2 3128 2>/dev/null; then
        print_status "PASS" "TCP connection to server2 HTTP proxy port (3128)"
    else
        print_status "FAIL" "TCP connection to server2 HTTP proxy port (3128)"
    fi
}

# Function to run Python comprehensive tests
run_python_tests() {
    echo ""
    echo "=== Python Comprehensive Tests ==="
    print_status "INFO" "Running comprehensive Python test suite..."
    
    if docker exec vpn-client python3 /tests/test_protocols.py; then
        print_status "PASS" "Python comprehensive test suite completed"
    else
        print_status "FAIL" "Python comprehensive test suite failed"
    fi
}

# Function to check IP addresses seen by server
check_ip_addresses() {
    echo ""
    echo "=== IP Address Verification ==="
    
    print_status "INFO" "Checking IP addresses seen by server..."
    
    # Direct connection
    echo "Direct connection IP:"
    docker exec vpn-client curl -s http://internet-server:80/ | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "Failed to get IP"
    
    # Via server2 (VMess chain - should show server1's IP)
    echo "Via server2 (VMess chain) IP:"
    docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/ | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "Failed to get IP"
    
    # Test if the IPs are different (indicating the proxy is working)
    direct_ip=$(docker exec vpn-client curl -s http://internet-server:80/ | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
    proxy_ip=$(docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/ | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
    
    if [ "$direct_ip" != "$proxy_ip" ] && [ -n "$direct_ip" ] && [ -n "$proxy_ip" ]; then
        print_status "PASS" "IP addresses are different - VMess proxy chain is working"
    else
        print_status "FAIL" "IP addresses are the same or failed to retrieve - VMess proxy chain may not be working"
    fi
}

# Function to test SSL connection timeouts and network censorship
test_ssl_censorship() {
    echo ""
    echo "=== SSL Connection & Network Censorship Tests ==="
    
    print_status "INFO" "Testing SSL connection timeout scenarios..."
    
    # Test 1: Direct HTTPS with timeout detection
    print_status "INFO" "Testing direct HTTPS connection with timeout detection..."
    timeout_output=$(docker exec vpn-client timeout 10 curl -vvv -k https://internet-server:443/ 2>&1)
    if echo "$timeout_output" | grep -q "SSL connection timeout"; then
        print_status "FAIL" "Direct HTTPS: SSL connection timeout detected"
    elif echo "$timeout_output" | grep -q "TLS handshake"; then
        print_status "PASS" "Direct HTTPS: TLS handshake successful"
    else
        print_status "WARN" "Direct HTTPS: Connection succeeded but no TLS info found"
    fi
    
    # Test 2: HTTPS via VMess with detailed timeout analysis
    print_status "INFO" "Testing HTTPS via VMess with timeout analysis..."
    vmess_timeout_output=$(docker exec vpn-client timeout 15 curl -vvv -k --proxy http://vpn-server2:3128 https://internet-server:443/ 2>&1)
    if echo "$vmess_timeout_output" | grep -q "SSL connection timeout"; then
        print_status "FAIL" "VMess HTTPS: SSL connection timeout detected"
        print_status "WARN" "This may indicate network censorship or DPI interference"
    elif echo "$vmess_timeout_output" | grep -q "TLS handshake"; then
        print_status "PASS" "VMess HTTPS: TLS handshake successful"
    else
        print_status "WARN" "VMess HTTPS: Unexpected connection behavior"
    fi
    
    # Test 3: External HTTPS site testing
    print_status "INFO" "Testing external HTTPS sites for censorship detection..."
    
    # Test httpbin.org
    print_status "INFO" "Testing httpbin.org HTTPS via VMess..."
    httpbin_result=$(docker exec vpn-client timeout 20 curl -s -k --proxy http://vpn-server2:3128 https://httpbin.org/ip 2>&1)
    if echo "$httpbin_result" | grep -q "origin"; then
        print_status "PASS" "httpbin.org HTTPS via VMess: Working"
        echo "Response: $httpbin_result"
    elif echo "$httpbin_result" | grep -q "SSL connection timeout"; then
        print_status "FAIL" "httpbin.org HTTPS via VMess: SSL timeout (possible censorship)"
    else
        print_status "FAIL" "httpbin.org HTTPS via VMess: Connection failed"
    fi
    
    # Test 4: Compare HTTP vs HTTPS success rates
    print_status "INFO" "Comparing HTTP vs HTTPS success rates..."
    
    http_success=0
    https_success=0
    
    for i in {1..3}; do
        if docker exec vpn-client curl -s -f -m 10 --proxy http://vpn-server2:3128 http://httpbin.org/ip >/dev/null 2>&1; then
            http_success=$((http_success + 1))
        fi
        
        if docker exec vpn-client curl -s -f -k -m 15 --proxy http://vpn-server2:3128 https://httpbin.org/ip >/dev/null 2>&1; then
            https_success=$((https_success + 1))
        fi
    done
    
    print_status "INFO" "HTTP success rate: $http_success/3"
    print_status "INFO" "HTTPS success rate: $https_success/3"
    
    if [ $http_success -eq 3 ] && [ $https_success -eq 0 ]; then
        print_status "WARN" "HTTP working but HTTPS failing - Strong indication of HTTPS censorship"
    elif [ $http_success -eq 3 ] && [ $https_success -lt 3 ]; then
        print_status "WARN" "HTTP more reliable than HTTPS - Possible partial HTTPS censorship"
    elif [ $http_success -eq 3 ] && [ $https_success -eq 3 ]; then
        print_status "PASS" "Both HTTP and HTTPS working reliably"
    else
        print_status "FAIL" "General connectivity issues detected"
    fi
}

# Function to test advanced anti-censorship features
test_anti_censorship() {
    echo ""
    echo "=== Anti-Censorship Feature Tests ==="
    
    print_status "INFO" "Testing VMess with different configurations..."
    
    # Test 1: Check if VMess is using standard TLS port (443) - good for evasion
    print_status "INFO" "Checking VMess port configuration..."
    if docker exec vpn-client nc -z vpn-server1 443 2>/dev/null; then
        print_status "PASS" "VMess using port 443 (standard HTTPS port - good for evasion)"
    else
        print_status "FAIL" "VMess port 443 not accessible"
    fi
    
    # Test 2: Protocol detection test
    print_status "INFO" "Testing protocol detection resistance..."
    
    # Send raw data to VMess port and check response
    vmess_probe=$(docker exec vpn-client timeout 5 nc -w 1 vpn-server1 443 < /dev/null 2>&1)
    if echo "$vmess_probe" | grep -q "HTTP\|html\|server"; then
        print_status "WARN" "VMess might be detectable (returns HTTP-like response)"
    else
        print_status "PASS" "VMess appears to be protocol-obfuscated (no clear HTTP response)"
    fi
    
    # Test 3: Traffic analysis resistance
    print_status "INFO" "Testing traffic pattern analysis..."
    
    # Make multiple requests and check for timing patterns
    start_time=$(date +%s.%N)
    for i in {1..5}; do
        docker exec vpn-client curl -s -f -m 10 --proxy http://vpn-server2:3128 http://httpbin.org/ip >/dev/null 2>&1
    done
    end_time=$(date +%s.%N)
    
    total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    avg_time=$(echo "scale=3; $total_time / 5" | bc -l 2>/dev/null || echo "0")
    
    print_status "INFO" "Average request time: ${avg_time}s"
    
    if [ $(echo "$avg_time > 1.0" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        print_status "WARN" "Slow response times may indicate throttling or analysis"
    else
        print_status "PASS" "Response times appear normal"
    fi
}

# Function to run performance tests
run_performance_tests() {
    echo ""
    echo "=== Performance Tests ==="
    
    print_status "INFO" "Running performance tests..."
    
    # Test response times
    echo "Response time comparison:"
    
    # Direct
    direct_time=$(docker exec vpn-client curl -s -w "%{time_total}" -o /dev/null http://internet-server:80/ 2>/dev/null)
    echo "Direct connection: ${direct_time}s"
    
    # Via server2 (VMess chain)
    vmess_time=$(docker exec vpn-client curl -s -w "%{time_total}" -o /dev/null --proxy http://vpn-server2:3128 http://internet-server:80/ 2>/dev/null)
    echo "Via server2 (VMess chain): ${vmess_time}s"
    
    # Calculate overhead
    if [ -n "$direct_time" ] && [ -n "$vmess_time" ]; then
        overhead=$(echo "$vmess_time - $direct_time" | bc -l 2>/dev/null || echo "calculation failed")
        echo "VMess overhead: ${overhead}s"
    fi
}

# Main execution function
main() {
    echo "Starting comprehensive VPN proxy chain testing with VMess protocol..."
    echo ""
    
    # Check if all containers are running
    print_status "INFO" "Checking container status..."
    
    containers=("internet-server" "vpn-server1" "vpn-server2" "vpn-client")
    for container in "${containers[@]}"; do
        if check_container "$container"; then
            print_status "PASS" "$container is running"
        else
            print_status "FAIL" "$container is not running"
            echo "Please start containers with: docker-compose up -d"
            exit 1
        fi
    done
    
    # Wait for services to be ready
    wait_for_service "internet-server" 80 "HTTP service"
    wait_for_service "internet-server" 443 "HTTPS service"
    wait_for_service "vpn-server1" 443 "Server1 VMess service"
    wait_for_service "vpn-server2" 3128 "Server2 HTTP proxy"
    
    # Run VMess-specific tests first
    check_vmess_connectivity
    
    # Run all test suites
    run_curl_tests
    run_advanced_tests
    run_tcp_tests
    check_ip_addresses
    run_performance_tests
    
    # Run new SSL and censorship tests
    test_ssl_censorship
    test_anti_censorship
    
    # Run Python comprehensive tests
    run_python_tests
    
    echo ""
    echo "=== Test Suite Complete ==="
    print_status "INFO" "Check the output above for any failed tests"
    print_status "INFO" "VMess protocol is now used between server2 and server1"
    print_status "INFO" "Detailed Python test results saved in container at /tmp/test_results.json"
}

# Help function
show_help() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  run, test     Run all tests"
    echo "  curl          Run only basic cURL tests"
    echo "  advanced      Run advanced protocol tests"
    echo "  tcp           Run TCP connection tests"
    echo "  vmess         Run VMess protocol tests"
    echo "  ssl           Run SSL timeout and censorship tests"
    echo "  censorship    Run anti-censorship feature tests"
    echo "  python        Run Python comprehensive tests"
    echo "  performance   Run performance tests"
    echo "  ip            Check IP addresses"
    echo "  help          Show this help message"
    echo ""
    echo "If no option is provided, all tests will be run."
}

# Parse command line arguments
case "$1" in
    "run"|"test"|"")
        main
        ;;
    "curl")
        run_curl_tests
        ;;
    "advanced")
        run_advanced_tests
        ;;
    "tcp")
        run_tcp_tests
        ;;
    "vmess")
        check_vmess_connectivity
        ;;
    "ssl")
        test_ssl_censorship
        ;;
    "censorship")
        test_anti_censorship
        ;;
    "python")
        run_python_tests
        ;;
    "performance")
        run_performance_tests
        ;;
    "ip")
        check_ip_addresses
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