# Cortex CLI Toolkit

A toolkit for running the Palo Alto Networks Cortex CLI for security scanning in CI/CD pipelines and local development. This repository provides **two approaches** to run the Cortex CLI:

1. **Container-based** - Run cortexcli in a Docker container with all dependencies pre-installed
2. **Binary-based** - Install cortexcli directly on your host system

## Overview

The Cortex CLI enables security scanning across your development workflow, supporting code analysis, container image scanning, and API security testing.

### Supported Scan Types

| Module | Description | Use Case |
|--------|-------------|----------|
| **Code Scan** | Scans for secrets, IaC misconfigurations, and SCA vulnerabilities | CI/CD pipelines, pre-commit checks |
| **Image Scan** | Scans container images for vulnerabilities, secrets, and malware | Container security, registry scanning |
| **API Scan** | Tests APIs for vulnerabilities using OpenAPI specifications | API security testing |

---

## Option 1: Container-Based (Recommended)

Run cortexcli in a Docker container with all required dependencies pre-installed. This is the recommended approach for CI/CD pipelines and consistent cross-environment usage.

### Available Container Images

| Dockerfile | Base Image | Use Case |
|------------|------------|----------|
| `Dockerfile.ubuntu` | Ubuntu 24.04 | General purpose, recommended for most users |
| `Dockerfile.amazonlinux` | Amazon Linux 2023 | AWS environments, ECS/EKS deployments |

### Quick Start

#### 1. Build the Image

**Ubuntu-based:**
```bash
docker build --platform linux/amd64 -f Dockerfile.ubuntu -t cortex-cli:ubuntu .
```

**Amazon Linux-based:**
```bash
docker build --platform linux/amd64 -f Dockerfile.amazonlinux -t cortex-cli:amazonlinux .
```

#### 2. Configure Credentials

```bash
cp cortex.env.example cortex.env
# Edit cortex.env with your Cortex API credentials
```

#### 3. Run a Scan

**Code Scan:**
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo
```

**Image Scan:**
```bash
docker run --rm \
  --env-file cortex.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --user $(id -u):$(id -g) \
  --group-add $(getent group docker | cut -d: -f3) \
  cortex-cli:ubuntu image scan nginx:latest
```

### Container Features

- All-in-one container with Java, Node.js, and all dependencies pre-installed
- Non-root user by default for security
- CI/CD ready - Works with GitHub Actions, GitLab CI, Jenkins, and more
- Private registry support - Scan images from ECR, ACR, GCR
- Multiple output formats - JSON, SARIF, JUnit XML, CycloneDX

---

## Option 2: Binary-Based (Direct Installation)

Install cortexcli directly on your host system. This approach is useful for:
- Systems where Docker is not available
- Custom automation scripts
- Direct integration with existing tooling

### Supported Platforms

- Amazon Linux 2023
- Ubuntu 20.04 / 22.04 / 24.04
- Debian 11 / 12

### Installation

See **[REQUIREMENTS_MANUAL_INSTALL.md](REQUIREMENTS_MANUAL_INSTALL.md)** for step-by-step instructions to install:
- Java 17 (required for API Security)
- Node.js 22 (required for Cloud Application Security)
- Docker client (required for Image Scanning)
- Hyperscan library (required by scanning engine)

### Quick Install (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt-get update && sudo apt-get install -y \
  openjdk-17-jre-headless docker.io jq libhyperscan5

# Install Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs

# Download cortexcli from your Cortex Cloud tenant and make executable
chmod +x cortexcli
sudo mv cortexcli /usr/local/bin/
```

---

## Image Scanning Script

The `cortex-scan.sh` script provides an automated workflow for scanning container images with additional features:

- Automatic dependency and CLI installation (optional)
- Checks if image exists locally, pulls if necessary
- Checks if image was already scanned in Cortex Cloud
- Queries vulnerability findings via Cortex XQL API
- Outputs results as JSON

### Usage

```bash
# Basic usage (credentials from environment)
export CORTEX_API_URL="https://api.your-region.paloaltonetworks.com"
export CORTEX_API_KEY="your_api_key"
export CORTEX_API_KEY_ID="your_api_key_id"
./cortex-scan.sh nginx:latest

# Save results to file
./cortex-scan.sh -o findings.json nginx:latest

# First-time setup with auto-install
./cortex-scan.sh --install -u <url> -k <key> -i <key_id> nginx:latest
```

See the script header for all available options.

---

## Prerequisites: Download Cortex CLI Binary

Before building the container or running the binary directly, you must download the `cortexcli` binary from your Cortex Cloud tenant:

1. Log into your Cortex Cloud tenant
2. Navigate to **Settings** → **Data Sources** → **+ Data Source**
3. Search for **Cortex CLI** → **Connect**
4. Select **Linux (amd64)** and copy the download command
5. Run the download command and place the `cortexcli` binary in this directory

---

## Project Structure

```
├── Dockerfile.ubuntu               # Ubuntu 24.04 container definition
├── Dockerfile.amazonlinux          # Amazon Linux 2023 container definition
├── cortex.env.example              # Credentials template
├── cortexcli                       # Cortex CLI binary (download from Cortex Cloud)
├── cortex-scan.sh                  # Image scanning automation script
├── REQUIREMENTS_MANUAL_INSTALL.md  # Manual installation guide for binary usage
├── INSTRUCTIONS.md                 # Detailed usage instructions
├── cortex-cli-docs.md              # Official Cortex CLI reference
└── README.md                       # This file
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Run Cortex Code Scan
  run: |
    docker run --rm \
      -e CORTEX_API_KEY=${{ secrets.CORTEX_API_KEY }} \
      -e CORTEX_API_KEY_ID=${{ secrets.CORTEX_API_KEY_ID }} \
      -e CORTEX_API_BASE_URL=${{ secrets.CORTEX_API_BASE_URL }} \
      -v "${{ github.workspace }}":/workspace \
      cortex-cli:ubuntu code scan \
        --directory /workspace \
        --branch ${{ github.ref_name }} \
        --repo-id ${{ github.repository }}
```

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for GitLab CI, Jenkins, and other examples.

---

## Documentation

| Document | Description |
|----------|-------------|
| [INSTRUCTIONS.md](INSTRUCTIONS.md) | Complete usage guide with examples |
| [REQUIREMENTS_MANUAL_INSTALL.md](REQUIREMENTS_MANUAL_INSTALL.md) | Manual installation for binary-based usage |
| [cortex-cli-docs.md](cortex-cli-docs.md) | Official Cortex CLI reference |

---

## Security Notes

- Never commit `cortex.env` to version control
- Use `--user $(id -u):$(id -g)` to match host permissions when running containers
- For image scans, mount Docker socket with appropriate group permissions
- The container runs as non-root user `cortex` by default

---

## Requirements

### Container-Based
- Docker (linux/amd64)
- Cortex Cloud API credentials (API Key, Key ID, Base URL)
- Cortex CLI binary (downloaded from your Cortex Cloud tenant)

### Binary-Based
- Linux x86_64 (Amazon Linux 2023, Ubuntu 20.04+, Debian 11+)
- Java 17+
- Node.js 22+
- Docker (for image scanning only)
- Hyperscan/Vectorscan library
- Cortex Cloud API credentials

---

## License

This project packages the Palo Alto Networks Cortex CLI. See [Palo Alto Networks](https://www.paloaltonetworks.com/) for licensing terms.
