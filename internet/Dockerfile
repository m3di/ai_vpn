FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY main.go .
RUN go mod init internet-server
RUN go build -o internet-server main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/internet-server .

EXPOSE 80
CMD ["./internet-server"] 