#!/bin/bash

echo "=== VPN Proxy Chain Comprehensive Test Suite ==="
echo "This script tests HTTP, HTTPS, file transfers, and TCP connections"
echo "through various proxy configurations."
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
    
    # Test 2: HTTP via server1
    print_status "INFO" "Testing HTTP via server1 proxy..."
    if docker exec vpn-client curl -s -f -m 10 --proxy http://vpn-server1:3128 http://internet-server:80/ >/dev/null 2>&1; then
        print_status "PASS" "HTTP via server1 proxy"
    else
        print_status "FAIL" "HTTP via server1 proxy"
    fi
    
    # Test 3: HTTP via server2 (full chain)
    print_status "INFO" "Testing HTTP via server2 proxy (full chain)..."
    if docker exec vpn-client curl -s -f -m 10 --proxy http://vpn-server2:3128 http://internet-server:80/ >/dev/null 2>&1; then
        print_status "PASS" "HTTP via server2 proxy (full chain)"
    else
        print_status "FAIL" "HTTP via server2 proxy (full chain)"
    fi
    
    # Test 4: HTTPS tests
    print_status "INFO" "Testing HTTPS connections..."
    
    # Direct HTTPS
    if docker exec vpn-client curl -s -f -k -m 10 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "Direct HTTPS connection"
    else
        print_status "FAIL" "Direct HTTPS connection"
    fi
    
    # HTTPS via server1
    if docker exec vpn-client curl -s -f -k -m 10 --proxy http://vpn-server1:3128 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "HTTPS via server1 proxy"
    else
        print_status "FAIL" "HTTPS via server1 proxy"
    fi
    
    # HTTPS via server2
    if docker exec vpn-client curl -s -f -k -m 10 --proxy http://vpn-server2:3128 https://internet-server:443/ >/dev/null 2>&1; then
        print_status "PASS" "HTTPS via server2 proxy (full chain)"
    else
        print_status "FAIL" "HTTPS via server2 proxy (full chain)"
    fi
}

# Function to run advanced tests
run_advanced_tests() {
    echo ""
    echo "=== Advanced Protocol Tests ==="
    
    # Test file download
    print_status "INFO" "Testing file download..."
    if docker exec vpn-client curl -s -f -m 10 http://internet-server:80/download -o /tmp/test_download.txt >/dev/null 2>&1; then
        print_status "PASS" "File download test"
    else
        print_status "FAIL" "File download test"
    fi
    
    # Test file upload
    print_status "INFO" "Testing file upload..."
    if docker exec vpn-client curl -s -f -m 10 -X POST -d "test upload data" http://internet-server:80/upload >/dev/null 2>&1; then
        print_status "PASS" "File upload test"
    else
        print_status "FAIL" "File upload test"
    fi
    
    # Test status endpoint
    print_status "INFO" "Testing status endpoint..."
    if docker exec vpn-client curl -s -f -m 10 http://internet-server:80/status >/dev/null 2>&1; then
        print_status "PASS" "Status endpoint test"
    else
        print_status "FAIL" "Status endpoint test"
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
    
    # TCP to proxy servers
    if docker exec vpn-client nc -z vpn-server1 3128 2>/dev/null; then
        print_status "PASS" "TCP connection to server1 proxy"
    else
        print_status "FAIL" "TCP connection to server1 proxy"
    fi
    
    if docker exec vpn-client nc -z vpn-server2 3128 2>/dev/null; then
        print_status "PASS" "TCP connection to server2 proxy"
    else
        print_status "FAIL" "TCP connection to server2 proxy"
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
    docker exec vpn-client curl -s http://internet-server:80/ | jq -r '.client_ip' 2>/dev/null || echo "Failed to get IP"
    
    # Via server1
    echo "Via server1 proxy IP:"
    docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/ | jq -r '.client_ip' 2>/dev/null || echo "Failed to get IP"
    
    # Via server2 (should show server1's IP)
    echo "Via server2 proxy IP (should show server1's IP):"
    docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/ | jq -r '.client_ip' 2>/dev/null || echo "Failed to get IP"
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
    
    # Via server1
    server1_time=$(docker exec vpn-client curl -s -w "%{time_total}" -o /dev/null --proxy http://vpn-server1:3128 http://internet-server:80/ 2>/dev/null)
    echo "Via server1: ${server1_time}s"
    
    # Via server2
    server2_time=$(docker exec vpn-client curl -s -w "%{time_total}" -o /dev/null --proxy http://vpn-server2:3128 http://internet-server:80/ 2>/dev/null)
    echo "Via server2 (full chain): ${server2_time}s"
}

# Main execution function
main() {
    echo "Starting comprehensive VPN proxy chain testing..."
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
    wait_for_service "vpn-server1" 3128 "Server1 proxy"
    wait_for_service "vpn-server2" 3128 "Server2 proxy"
    
    # Run all test suites
    run_curl_tests
    run_advanced_tests
    run_tcp_tests
    check_ip_addresses
    run_performance_tests
    
    # Run Python comprehensive tests
    run_python_tests
    
    echo ""
    echo "=== Test Suite Complete ==="
    print_status "INFO" "Check the output above for any failed tests"
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