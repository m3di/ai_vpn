FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Xray
RUN curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip && \
    unzip xray.zip && \
    chmod +x xray && \
    mv xray /usr/local/bin/ && \
    rm -f xray.zip

# Create directories
RUN mkdir -p /etc/xray /var/log/xray

# Copy Xray configuration and startup script
COPY xray-config.json /etc/xray/config.json
COPY start-xray.sh /usr/local/bin/start-xray
RUN chmod +x /usr/local/bin/start-xray

EXPOSE 443

CMD ["/usr/local/bin/start-xray"] 