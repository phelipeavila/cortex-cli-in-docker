# Use Ubuntu 24.04 (Noble Numbat) as the base image
# Cortex CLI binary is amd64 only - enforce platform via build arg
ARG TARGETPLATFORM=linux/amd64
FROM ubuntu:24.04
# FROM debian:bookwdebian orm-slim

# Metadata labels for better image management
LABEL maintainer="security-team" \
      description="Cortex CLI container for security scanning (API Security, CWP, Cloud AppSec)" \
      version="1.0"

# Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"

# Enable universe repository and install dependencies
# - curl, gnupg, ca-certificates: For secure downloads and repo setup
# - openjdk-17-jre-headless: Required for API Security and CWP modules (Java 11+ required)
# - docker.io: Docker client required for 'image scan' (communicating with host daemon)
# - git: Required for 'code scan' to interact with repositories
# - jq: Required for cURL-based operations per docs
# - libhyperscan5: Pattern matching library required by CLI (falls back to vectorscan if not available)
RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common \
    && add-apt-repository -y universe \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
        openjdk-17-jre-headless \
        git \
        docker.io \
        jq \
    && (apt-get install -y --no-install-recommends libhyperscan5 \
        || apt-get install -y --no-install-recommends libvectorscan5) \
    && apt-get purge -y software-properties-common \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Hyperscan compatibility symlink (only needed if vectorscan was installed)
RUN if [ -f /usr/lib/x86_64-linux-gnu/libvectorscan.so.5 ]; then \
        ln -sf /usr/lib/x86_64-linux-gnu/libvectorscan.so.5 /usr/lib/x86_64-linux-gnu/libhyperscan.so.5; \
    fi

# Install Node.js v22 (Required for Cloud Application Security module)
# We use the official NodeSource repository for the specific version 22.x
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user 'cortex' for security best practices
# We create a group 'cortex' and user 'cortex' with a home directory
# Also add to 'docker' group for socket access when mounted
RUN groupadd -r cortex && useradd -r -g cortex -m -s /bin/bash cortex \
    && usermod -aG docker cortex

# Copy the cortexcli binary from the build context
# Ensure you have the 'cortexcli' binary in the same directory as this Dockerfile
COPY --chmod=755 cortexcli /usr/local/bin/cortexcli

# Set the working directory
WORKDIR /workspace

# Set ownership of the workspace to the non-root user
RUN chown cortex:cortex /workspace

# Switch to the non-root user
USER cortex

# Healthcheck to verify CLI is functional
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD cortexcli --version || exit 1

# Entrypoint: Default to running the cortexcli
ENTRYPOINT ["cortexcli"]

# Default command: Show help
CMD ["--help"]
