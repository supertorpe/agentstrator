FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    socat \
    python3 \
    python3-pip \
    libgtk-3-0 \
    libwebkit2gtk-4.0-37 \
    fonts-dejavu \
    fontconfig \
    build-essential

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt install -y nodejs

RUN rm -rf /var/lib/apt/lists/*

RUN npm config set prefix /usr/local
