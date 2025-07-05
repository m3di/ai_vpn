package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
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

func basicHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	response := fmt.Sprintf(`{
  "service": "basic-http",
  "client_ip": "%s",
  "method": "%s",
  "path": "%s",
  "user_agent": "%s",
  "timestamp": "%s",
  "protocol": "%s"
}`, clientIP, r.Method, r.URL.Path, r.UserAgent(), time.Now().Format(time.RFC3339), r.Proto)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
	
	log.Printf("HTTP Request from %s - Method: %s, Path: %s", clientIP, r.Method, r.URL.Path)
}

func httpsHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	response := fmt.Sprintf(`{
  "service": "https",
  "client_ip": "%s",
  "method": "%s",
  "path": "%s",
  "user_agent": "%s",
  "timestamp": "%s",
  "protocol": "%s",
  "tls_version": "%s"
}`, clientIP, r.Method, r.URL.Path, r.UserAgent(), time.Now().Format(time.RFC3339), r.Proto, getTLSVersion(r))
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
	
	log.Printf("HTTPS Request from %s - Method: %s, Path: %s", clientIP, r.Method, r.URL.Path)
}

func getTLSVersion(r *http.Request) string {
	if r.TLS == nil {
		return "none"
	}
	switch r.TLS.Version {
	case tls.VersionTLS10:
		return "TLS 1.0"
	case tls.VersionTLS11:
		return "TLS 1.1"
	case tls.VersionTLS12:
		return "TLS 1.2"
	case tls.VersionTLS13:
		return "TLS 1.3"
	default:
		return "unknown"
	}
}

func downloadHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	// Simulate a file download
	content := fmt.Sprintf("This is a test download file from %s at %s\n", clientIP, time.Now().Format(time.RFC3339))
	for i := 0; i < 100; i++ {
		content += fmt.Sprintf("Line %d: Sample data for download test\n", i+1)
	}
	
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", "attachment; filename=test-download.txt")
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, content)
	
	log.Printf("Download request from %s", clientIP)
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte(`{"error": "Method not allowed", "expected": "POST"}`))
		return
	}
	
	// Read the uploaded data
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "Failed to read upload data"}`))
		return
	}
	
	response := fmt.Sprintf(`{
  "service": "upload",
  "client_ip": "%s",
  "uploaded_size": %d,
  "content_type": "%s",
  "timestamp": "%s"
}`, clientIP, len(body), r.Header.Get("Content-Type"), time.Now().Format(time.RFC3339))
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
	
	log.Printf("Upload request from %s - Size: %d bytes", clientIP, len(body))
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := getClientIP(r)
	
	response := fmt.Sprintf(`{
  "service": "status",
  "client_ip": "%s",
  "server_time": "%s",
  "uptime": "simulated",
  "services": ["http:80", "https:443", "download", "upload", "status"],
  "proxy_test": "ok"
}`, clientIP, time.Now().Format(time.RFC3339))
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
	
	log.Printf("Status request from %s", clientIP)
}

func main() {
	// HTTP routes
	http.HandleFunc("/", basicHandler)
	http.HandleFunc("/download", downloadHandler)
	http.HandleFunc("/upload", uploadHandler)
	http.HandleFunc("/status", statusHandler)
	
	// HTTPS routes
	httpsServer := &http.Server{
		Addr:    ":443",
		Handler: http.HandlerFunc(httpsHandler),
	}
	
	// Start HTTPS server in a goroutine
	go func() {
		log.Println("HTTPS server starting on port 443...")
		if err := httpsServer.ListenAndServeTLS("server.crt", "server.key"); err != nil {
			log.Printf("HTTPS server error: %v", err)
		}
	}()
	
	// Start HTTP server
	log.Println("HTTP server starting on port 80...")
	log.Fatal(http.ListenAndServe(":80", nil))
} 