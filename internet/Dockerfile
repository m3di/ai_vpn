FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY main.go .
RUN go mod init internet-server
RUN go build -o internet-server main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates openssl
WORKDIR /root/

# Generate self-signed certificate for testing
RUN openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes \
    -subj "/C=US/ST=Test/L=Test/O=Test/CN=internet-server"

COPY --from=builder /app/internet-server .

EXPOSE 80 443
CMD ["./internet-server"] 