FROM alpine:latest

# Install squid proxy
RUN apk --no-cache add squid curl

# Copy squid configuration
COPY squid.conf /etc/squid/squid.conf

# Create squid directories
RUN mkdir -p /var/cache/squid /var/log/squid && \
    chown -R squid:squid /var/cache/squid /var/log/squid

# Initialize squid cache
RUN squid -z

EXPOSE 3128 8080

CMD ["squid", "-f", "/etc/squid/squid.conf", "-NYCd", "1"] 