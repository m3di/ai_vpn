#!/usr/bin/env python3
"""
Simplified VPN Proxy Chain Testing Script
Tests basic HTTP connections through the proxy chain using standard Python libraries.
"""

import socket
import time
import json
import sys
import os

class VPNTester:
    def __init__(self):
        self.results = []
        self.target_host = "internet-server"
        self.http_port = 80
        self.https_port = 443
        
    def log_result(self, test_name, status, details, proxy=None):
        """Log test results"""
        result = {
            "test": test_name,
            "status": status,
            "details": details,
            "proxy": proxy,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.results.append(result)
        print(f"[{status}] {test_name}: {details}")
        
    def test_tcp_connection(self, host, port, proxy_host=None, proxy_port=None):
        """Test raw TCP connection"""
        try:
            if proxy_host:
                # Connect through proxy using CONNECT method
                proxy_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                proxy_socket.settimeout(10)
                proxy_socket.connect((proxy_host, proxy_port))
                
                connect_request = f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}:{port}\r\n\r\n"
                proxy_socket.send(connect_request.encode())
                
                response = proxy_socket.recv(1024).decode()
                proxy_socket.close()
                
                if "200 Connection established" in response:
                    self.log_result(f"TCP Connect to {host}:{port} via {proxy_host}", "PASS", 
                                   "Connection established")
                    return True
                else:
                    self.log_result(f"TCP Connect to {host}:{port} via {proxy_host}", "FAIL", 
                                   f"Proxy response: {response[:100]}")
                    return False
            else:
                # Direct connection
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(10)
                result = sock.connect_ex((host, port))
                sock.close()
                
                if result == 0:
                    self.log_result(f"TCP Connect to {host}:{port} Direct", "PASS", 
                                   "Connection successful")
                    return True
                else:
                    self.log_result(f"TCP Connect to {host}:{port} Direct", "FAIL", 
                                   f"Connection failed with code {result}")
                    return False
        except Exception as e:
            test_name = f"TCP Connect to {host}:{port} {'via ' + proxy_host if proxy_host else 'Direct'}"
            self.log_result(test_name, "FAIL", str(e))
            return False
    
    def test_curl_command(self, url, proxy=None):
        """Test HTTP using curl command"""
        try:
            if proxy:
                cmd = f"curl -s -f -m 10 --proxy {proxy} {url}"
            else:
                cmd = f"curl -s -f -m 10 {url}"
            
            result = os.system(cmd + " >/dev/null 2>&1")
            
            test_name = f"HTTP {'via ' + proxy if proxy else 'Direct'} - {url}"
            if result == 0:
                self.log_result(test_name, "PASS", "cURL request successful")
                return True
            else:
                self.log_result(test_name, "FAIL", f"cURL failed with code {result}")
                return False
        except Exception as e:
            test_name = f"HTTP {'via ' + proxy if proxy else 'Direct'} - {url}"
            self.log_result(test_name, "FAIL", str(e))
            return False
    
    def run_basic_tests(self):
        """Run basic connectivity tests"""
        print("=== Starting Basic VPN Proxy Chain Tests ===\n")
        
        # Test 1: TCP connectivity
        print("--- Testing TCP Connections ---")
        self.test_tcp_connection(self.target_host, self.http_port)
        self.test_tcp_connection(self.target_host, self.https_port)
        self.test_tcp_connection("vpn-server1", 3128)
        self.test_tcp_connection("vpn-server2", 3128)
        
        print("\n--- Testing HTTP Connections ---")
        # Test 2: HTTP connections
        base_url = f"http://{self.target_host}:{self.http_port}/"
        
        # Direct connection
        self.test_curl_command(base_url)
        
        # Via server1
        self.test_curl_command(base_url, "http://vpn-server1:3128")
        
        # Via server2 (full chain)
        self.test_curl_command(base_url, "http://vpn-server2:3128")
        
        # Test different endpoints
        print("\n--- Testing Different Endpoints ---")
        self.test_curl_command(f"http://{self.target_host}:{self.http_port}/status")
        self.test_curl_command(f"http://{self.target_host}:{self.http_port}/status", "http://vpn-server1:3128")
        self.test_curl_command(f"http://{self.target_host}:{self.http_port}/status", "http://vpn-server2:3128")
        
        # Generate summary
        self.generate_summary()
        
    def generate_summary(self):
        """Generate test summary"""
        print("\n=== Test Summary ===")
        
        total_tests = len(self.results)
        passed_tests = len([r for r in self.results if r['status'] == 'PASS'])
        failed_tests = total_tests - passed_tests
        
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {failed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if failed_tests > 0:
            print("\nFailed Tests:")
            for result in self.results:
                if result['status'] == 'FAIL':
                    print(f"  - {result['test']}: {result['details']}")
        
        # Save results to file
        try:
            with open('/tmp/test_results.json', 'w') as f:
                json.dump(self.results, f, indent=2)
            print("\nDetailed results saved to /tmp/test_results.json")
        except Exception as e:
            print(f"\nCould not save results: {e}")

if __name__ == "__main__":
    tester = VPNTester()
    tester.run_basic_tests() 