# Stage 1: Download & extract binaries
FROM ubuntu:24.04 AS autobuilds

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        wget unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/ton-blockchain/ton/releases/latest/download/ton-linux-x86_64.zip && \
    unzip ton-linux-x86_64.zip && \
    chmod +x generate-random-id rldp-http-proxy

# Stage 2: Runtime
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies + libfuse2 for AppImage support
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        libfuse2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /ton-proxy

# Copy binaries from builder stage
COPY --from=autobuilds /app/generate-random-id /usr/local/bin/generate-random-id
COPY --from=autobuilds /app/rldp-http-proxy /usr/local/bin/rldp-http-proxy

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh

# Permissions (optional but good practice)
RUN chmod +x /usr/local/bin/generate-random-id \
            /usr/local/bin/rldp-http-proxy \
            /entrypoint.sh

# No USER directive → runs as root (as decided)

EXPOSE 8080
EXPOSE 3333/udp

ENTRYPOINT ["/entrypoint.sh"]
