# Cortex CLI in Docker

A containerized version of the Palo Alto Networks Cortex CLI for security scanning in CI/CD pipelines and local development.

## Overview

This project packages the Cortex CLI into a Docker container with all required dependencies, enabling consistent security scanning across different environments without manual installation.

### Supported Scan Types

| Module | Description | Use Case |
|--------|-------------|----------|
| **Code Scan** | Scans for secrets, IaC misconfigurations, and SCA vulnerabilities | CI/CD pipelines, pre-commit checks |
| **Image Scan** | Scans container images for vulnerabilities, secrets, and malware | Container security, registry scanning |
| **API Scan** | Tests APIs for vulnerabilities using OpenAPI specifications | API security testing |

## Quick Start

### 1. Build the Image

```bash
docker build --platform linux/amd64 -t cortex-cli:latest .
```

### 2. Configure Credentials

```bash
cp cortex.env.example cortex.env
# Edit cortex.env with your Cortex API credentials
```

### 3. Run a Scan

**Code Scan:**
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:latest code scan \
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
  cortex-cli:latest image scan nginx:latest
```

## Features

- ✅ **All-in-one container** - Java, Node.js, and all dependencies pre-installed
- ✅ **Non-root by default** - Runs as `cortex` user for security
- ✅ **CI/CD ready** - Works with GitHub Actions, GitLab CI, Jenkins, and more
- ✅ **Private registry support** - Scan images from ECR, ACR, GCR
- ✅ **Multiple output formats** - JSON, SARIF, JUnit XML, CycloneDX

## Requirements

- Docker (linux/amd64)
- Cortex Cloud API credentials (API Key, Key ID, Base URL)
- **Cortex CLI binary** (downloaded from your Cortex Cloud tenant)

## Prerequisites: Download Cortex CLI

Before building the image, you must download the `cortexcli` binary from your Cortex Cloud tenant:

1. Log into your Cortex Cloud tenant
2. Navigate to **Settings** → **Data Sources** → **+ Data Source**
3. Search for **Cortex CLI** → **Connect**
4. Select **Linux (amd64)** and copy the download command
5. Run the download command and place the `cortexcli` binary in this directory


## Documentation

- **[INSTRUCTIONS.md](INSTRUCTIONS.md)** - Complete usage guide with examples
- **[cortex-cli-docs.md](cortex-cli-docs.md)** - Official Cortex CLI reference

## Project Structure

```
├── Dockerfile           # Container definition
├── cortex.env.example   # Credentials template
├── cortexcli            # Cortex CLI binary (download from Cortex Cloud - not included)
├── INSTRUCTIONS.md      # Detailed usage instructions
└── README.md            # This file
```

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
      cortex-cli:latest code scan \
        --directory /workspace \
        --branch ${{ github.ref_name }} \
        --repo-id ${{ github.repository }}
```

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for GitLab CI, Jenkins, and other examples.

## Security Notes

- Never commit `cortex.env` to version control
- Use `--user $(id -u):$(id -g)` to match host permissions
- For image scans, mount Docker socket with appropriate group permissions

## License

This project packages the Palo Alto Networks Cortex CLI. See [Palo Alto Networks](https://www.paloaltonetworks.com/) for licensing terms.
