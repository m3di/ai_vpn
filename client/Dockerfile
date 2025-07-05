FROM alpine:latest

# Install curl and networking tools
RUN apk --no-cache add curl wget busybox-extras netcat-openbsd
 
# Keep container running
CMD ["sh", "-c", "while true; do sleep 30; done"] 