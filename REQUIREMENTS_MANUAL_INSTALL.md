# Manual Installation Guide: Cortex CLI

This guide provides step-by-step instructions for manually installing the required dependencies for the Palo Alto Networks Cortex CLI on **Amazon Linux 2023** and **Ubuntu/Debian**.

## Supported Platforms
*   **Amazon Linux 2023 (AL2023)**
*   **Ubuntu 20.04 / 22.04 / 24.04**
*   **Debian 11 / 12**

---

# 1. Amazon Linux 2023

## Prerequisites
*   **Root/Sudo Access**: You must have `sudo` privileges.

### Step 1: Update System & Install Core Tools

First, update your package repositories and install the base system utilities. This includes **Java 17** (required for API Security), **Docker** (required for Image Scanning), and utilities like `patchelf` and `zstd`.

```bash
# Update system repositories
sudo dnf update -y

# Install core dependencies
# --allowerasing is used to resolve potential conflicts with curl-minimal
sudo dnf install -y --allowerasing \
    shadow-utils \
    patchelf \
    zstd \
    curl \
    git \
    jq \
    tar \
    gzip \
    findutils \
    java-17-amazon-corretto-headless \
    docker
```

> **Note on Docker:** This command installs the Docker binaries. You must ensure the Docker daemon is running separately if you intend to perform Image Scans.

### Step 2: Install Node.js v22

The Cortex Cloud Application Security module requires a modern Node.js runtime. We use the official NodeSource repository.

```bash
# Setup NodeSource repository for Node.js 22.x
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -

# Install Node.js
sudo dnf install -y nodejs
```

### Step 3: Install Hyperscan (libhs)

**Important:** The **Hyperscan** library (`libhs.so.5`) is a required dependency for the Cortex scanning engine but is **not** available in the standard Amazon Linux 2023 repositories.

To resolve this, we install a binary-compatible RPM from the **Fedora 35** archives.

**Why Fedora 35?**
Amazon Linux 2023 is based on Fedora but has a specific version of the C++ Standard Library (`libstdc++`) that supports up to `GLIBCXX_3.4.29` (in AL2023.6) and `GLIBCXX_3.4.33` (in AL2023.10).
*   **Fedora 35's Hyperscan** requires `GLIBCXX_3.4.29`, making it perfectly compatible with **all** versions of Amazon Linux 2023.
*   **Newer Fedora versions** (36/37+) require newer GLIBCXX symbols not available in older AL2023 patch versions, which would cause the scanner to crash.

```bash
# Install Hyperscan directly from the Fedora archive
sudo rpm -Uvh --nodeps "https://d2lzkl7pfhq30w.cloudfront.net/pub/archive/fedora/linux/releases/35/Everything/x86_64/os/Packages/h/hyperscan-5.4.0-3.fc35.x86_64.rpm"
```

---

# 2. Ubuntu / Debian

## Prerequisites
*   **Root/Sudo Access**: You must have `sudo` privileges.

### Step 1: Update System & Install Core Tools

Install the necessary dependencies including Java (OpenJDK 17), Docker, and standard utilities.

```bash
# Update repositories
sudo apt-get update

# Install core dependencies
# openjdk-17-jre-headless: Required for API Security and CWP modules
# docker.io: Docker client required for 'image scan'
# libhyperscan5 / libvectorscan5: Pattern matching library required by CLI
sudo apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    openjdk-17-jre-headless \
    git \
    docker.io \
    jq \
    software-properties-common
```

### Step 2: Install Hyperscan / Vectorscan

The Cortex CLI requires `libhyperscan.so.5`. Ubuntu 20.04/22.04 typically provide `libhyperscan5`. Ubuntu 24.04 and newer may provide `libvectorscan5` (a compatible fork).

```bash
# Try to install hyperscan first
if apt-cache search libhyperscan5 | grep -q libhyperscan5; then
    sudo apt-get install -y libhyperscan5
else
    # Fallback to vectorscan (Ubuntu 24.04+)
    sudo apt-get install -y libvectorscan5
    
    # Create compatibility symlink
    # Vectorscan is a drop-in replacement, but the CLI looks for "libhyperscan.so.5"
    if [ -f /usr/lib/x86_64-linux-gnu/libvectorscan.so.5 ]; then
        sudo ln -sf /usr/lib/x86_64-linux-gnu/libvectorscan.so.5 /usr/lib/x86_64-linux-gnu/libhyperscan.so.5
    fi
fi
```

### Step 3: Install Node.js v22

Install Node.js v22 from the official NodeSource repository.

```bash
# Setup NodeSource repository for Node.js 22.x
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -

# Install Node.js
sudo apt-get install -y nodejs
```

---

# 3. Verification & Setup (All Platforms)

Run the following commands to ensure all dependencies are correctly installed:

```bash
# 1. Check Java (Should be 17.x)
java -version

# 2. Check Node.js (Should be 22.x)
node -v

# 3. Check Docker Client
docker --version

# 4. Check Hyperscan (Amazon Linux)
rpm -q hyperscan

# 4. Check Hyperscan (Ubuntu/Debian)
dpkg -l | grep -E "hyperscan|vectorscan"
```

## Next Steps

Once dependencies are installed:
1.  Download the `cortexcli` binary from your Cortex Cloud tenant.
2.  Make it executable: `chmod +x cortexcli`.
3.  Move it to your path: `sudo mv cortexcli /usr/local/bin/`.
4.  Run `cortexcli --version` to verify functionality.

```