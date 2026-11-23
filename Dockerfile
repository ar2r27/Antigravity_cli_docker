FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color \
    HOME=/home/antigravity \
    PATH=/usr/local/bin:/home/antigravity/.local/bin:$PATH

# Install base utilities, runtime tools, compilers, ttyd, gosu, and docker cli
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    sudo \
    tzdata \
    locales \
    openssh-client \
    gnupg \
    gosu \
    ttyd \
    docker.io \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    nano \
    procps \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create / configure non-root user antigravity (UID 1000, GID 1000) with passwordless sudo
# Handles Ubuntu 24.04 pre-existing 'ubuntu' user (UID 1000) cleanly
RUN if id -u ubuntu >/dev/null 2>&1; then \
        usermod -l antigravity -d /home/antigravity -m ubuntu && \
        groupmod -n antigravity ubuntu; \
    else \
        groupadd -g 1000 antigravity && \
        useradd -m -s /bin/bash -u 1000 -g 1000 antigravity; \
    fi && \
    usermod -aG sudo antigravity && \
    echo "antigravity ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/antigravity && \
    chmod 0440 /etc/sudoers.d/antigravity

# Install official Google Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin \
    && (cp /home/antigravity/.local/bin/agy /usr/local/bin/agy 2>/dev/null || true) \
    && chmod +x /usr/local/bin/agy \
    && agy --version

# Create workspace and data directories
RUN mkdir -p /workspace \
             /home/antigravity/.gemini/config \
             /home/antigravity/.gemini/antigravity-cli \
             /home/antigravity/.config \
             /home/antigravity/.local/bin \
             /home/antigravity/.cache \
    && chown -R antigravity:antigravity /workspace /home/antigravity

# Copy entrypoint and helper scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY bin/ /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/agy-* 2>/dev/null || true

WORKDIR /workspace

EXPOSE 7681

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["agy", "remote-control", "serve"]
