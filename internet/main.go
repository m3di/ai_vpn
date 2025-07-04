package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
)

func getClientIP(r *http.Request) string {
	// For VPN experiment, we want to see the proxy server IP, not the original client IP
	// So we prioritize RemoteAddr over forwarded headers
	
	// Get the direct connection IP (this will be the proxy server IP)
	ip := r.RemoteAddr
	
	// Remove port if present
	if strings.Contains(ip, ":") {
		ip = strings.Split(ip, ":")[0]
	}
	
	return ip
}

func handler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	response := fmt.Sprintf(`{
  "client_ip": "%s",
  "method": "%s",
  "path": "%s",
  "user_agent": "%s",
  "timestamp": "%s"
}`, clientIP, r.Method, r.URL.Path, r.UserAgent(), fmt.Sprintf("%d", 1))
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
	
	log.Printf("Request from %s - Method: %s, Path: %s", clientIP, r.Method, r.URL.Path)
}

func main() {
	http.HandleFunc("/", handler)
	
	log.Println("Internet server starting on port 80...")
	log.Fatal(http.ListenAndServe(":80", nil))
} 