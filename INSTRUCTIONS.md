# Cortex CLI Docker Container Instructions

This document provides instructions for building and using the Cortex CLI Docker container.

## Prerequisites

*   **Docker**: Ensure Docker is installed and running on your system.
*   **Cortex CLI Binary**: The `cortexcli` binary (linux-amd64) must be downloaded from your Cortex Cloud tenant.
*   **Cortex Credentials**: You need your API Key, Key ID, and Base URL from your Cortex tenant.
*   **Platform**: This container is built for `linux/amd64` only.

### Download Cortex CLI Binary

1. Log into your Cortex Cloud tenant
2. Navigate to **Settings** → **Data Sources** → **+ Data Source**
3. Search for **Cortex CLI** → **Connect**
4. Select **Linux (amd64)** as the operating system
5. Copy and run the download command


## 1. Build the Image

Run the following command in the directory containing the Dockerfile and `cortexcli` binary:

**Ubuntu-based:**
```bash
docker build --platform linux/amd64 -f Dockerfile.ubuntu -t cortex-cli:ubuntu .
```

**Amazon Linux-based:**
```bash
docker build --platform linux/amd64 -f Dockerfile.amazonlinux -t cortex-cli:amazonlinux .
```

> **Note:** The examples below use `cortex-cli:ubuntu`. Replace with `cortex-cli:amazonlinux` if using the Amazon Linux image.

## 2. Authentication Setup

### Required Environment Variables
*   `CORTEX_API_KEY` - Your API key secret
*   `CORTEX_API_KEY_ID` - Your API key ID
*   `CORTEX_API_BASE_URL` - Your Cortex tenant URL

### Option A: Using an Environment File (Recommended)

Create a `cortex.env` file with your credentials:

```bash
# cortex.env
CORTEX_API_KEY_ID=your-api-key-id
CORTEX_API_KEY=your-api-key-secret
CORTEX_API_BASE_URL=https://api-your-tenant.xdr.us.paloaltonetworks.com
```


Run using the env file:
```bash
docker run --rm --env-file cortex.env cortex-cli:ubuntu --version
```

### Option B: Inline Environment Variables

Pass credentials directly (useful for CI/CD or one-off commands):
```bash
docker run --rm \
  -e CORTEX_API_KEY="<your_key>" \
  -e CORTEX_API_KEY_ID="<your_key_id>" \
  -e CORTEX_API_BASE_URL="<your_url>" \
  cortex-cli:ubuntu --version
```

---

## 3. Running Scans

### Code Scan (Cloud Application Security)

Scans code for Secrets, IaC misconfigurations, and SCA vulnerabilities.

**Basic scan (using env file):**
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --create-repo-if-missing
```

**With JSON output (using inline vars):**
```bash
docker run --rm \
  -e CORTEX_API_KEY=$CORTEX_API_KEY \
  -e CORTEX_API_KEY_ID=$CORTEX_API_KEY_ID \
  -e CORTEX_API_BASE_URL=$CORTEX_API_BASE_URL \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --output json \
    --output-file-path /workspace/scan-results.json
```

### Image Scan (Cloud Workload Protection)

Scans container images for vulnerabilities, secrets, and malware.

**Option 1: Use host's docker group (recommended)**
```bash
docker run --rm \
  --env-file cortex.env \
  --group-add $(getent group docker | cut -d: -f3) \
  -v /var/run/docker.sock:/var/run/docker.sock \
  cortex-cli:ubuntu image scan <image_name>
```

**Option 2: Run as root (simpler but less secure)**
```bash
docker run --rm --user root \
  --env-file cortex.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  cortex-cli:ubuntu image scan <image_name>
```

**Scanning a .tar archive (no socket needed):**
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu image scan --archive /workspace/my-image.tar
```

### Scanning Images from Private Registries

When scanning images from private registries (AWS ECR, Azure ACR, GCR, etc.), you must first pull the image to make it available locally.

**Important:** Cortex CLI does not use standard Docker credentials when pulling images. Always pre-pull the image before scanning.

#### Option 1: Pre-pull on Host (Recommended)

Login and pull the image on your host first, then scan:

```bash
# Step 1: Login to your registry
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-west-2.amazonaws.com

# Step 2: Pull the image
docker pull 123456789.dkr.ecr.us-west-2.amazonaws.com/my-app:latest

# Step 3: Scan (image is already local)
docker run --rm \
  --env-file cortex.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --user $(id -u):$(id -g) \
  --group-add $(getent group docker | cut -d: -f3) \
  cortex-cli:ubuntu image scan 123456789.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
```

#### Option 2: Export to Archive (Most Portable)

Save the image as a tar file and scan without registry access:

```bash
# Pull and save on a machine with registry access
docker pull 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
docker save -o my-app.tar 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest

# Scan the archive (no registry auth or docker socket needed)
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu image scan --archive /workspace/my-app.tar
```

#### AWS ECR Quick Reference

```bash
# One-liner: Login, pull, and scan
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com && \
  docker pull $ECR_IMAGE && \
  docker run --rm --env-file cortex.env \
    -v /var/run/docker.sock:/var/run/docker.sock --user root \
    cortex-cli:ubuntu image scan $ECR_IMAGE
```

#### Azure ACR Quick Reference

```bash
# Login to ACR
az acr login --name myregistry

# Scan the image
docker run --rm --env-file cortex.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.docker/config.json:/home/cortex/.docker/config.json:ro \
  --user root \
  cortex-cli:ubuntu image scan myregistry.azurecr.io/my-app:latest
```

#### Google Artifact Registry Quick Reference

```bash
# Configure Docker for GCR/Artifact Registry
gcloud auth configure-docker us-docker.pkg.dev

# Scan the image
docker run --rm --env-file cortex.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.docker/config.json:/home/cortex/.docker/config.json:ro \
  --user root \
  cortex-cli:ubuntu image scan us-docker.pkg.dev/my-project/my-repo/my-app:latest
```

### API Scan (API Security)

Requires an OpenAPI specification file and network access to reach the target application.

**Basic API scan:**
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)/specs":/specs \
  cortex-cli:ubuntu api scan \
    --api-spec-file /specs/openapi.json \
    --scanned-app-url http://target-app.com
```

**With authentication file:**
```bash
docker run --rm \
  -e CORTEX_API_KEY=$CORTEX_API_KEY \
  -e CORTEX_API_KEY_ID=$CORTEX_API_KEY_ID \
  -e CORTEX_API_BASE_URL=$CORTEX_API_BASE_URL \
  -v "$(pwd)/specs":/specs \
  cortex-cli:ubuntu api scan \
    --api-spec-file /specs/openapi.json \
    --scanned-app-url http://target-app.com \
    --auth-file /specs/auth-file.yaml
```

**Note:** For scanning apps on `localhost`, use `--network host` or the host's IP address instead of `localhost`/`127.0.0.1`.

---

## 4. Advanced Use Cases

### Generate SBOM (Software Bill of Materials)

Generate an SBOM for a container image without uploading to Cortex:
```bash
docker run --rm \
  --env-file cortex.env \
  --group-add $(getent group docker | cut -d: -f3) \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu image sbom <image_name> \
    --output-file-path /workspace/sbom.json
```

### Scan Specific Frameworks Only

Scan only for specific issues (e.g., Terraform misconfigurations):
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --framework TERRAFORM
```

Scan for secrets only:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --framework SECRETS
```

Skip specific frameworks:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --skip-framework SCA
```

### Local-Only Scan (No Upload)

Run scans without uploading results to Cortex tenant:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --upload-mode no-upload \
    --output json \
    --output-file-path /workspace/local-results.json
```

### Soft Fail Mode (CI/CD Friendly)

Continue pipeline even if vulnerabilities are found (exit code 0):
```bash
docker run --rm \
  --env-file cortex.env \
  --soft-fail \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo
```

### Proxy Configuration

For environments behind a corporate proxy:
```bash
docker run --rm \
  --env-file cortex.env \
  -e HTTP_PROXY=http://proxy.company.com:8080 \
  -e HTTPS_PROXY=http://proxy.company.com:8080 \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo
```

With custom CA certificate:
```bash
docker run --rm \
  --env-file cortex.env \
  -e HTTPS_PROXY=http://proxy.company.com:8080 \
  -v "$(pwd)":/workspace \
  -v /path/to/ca-cert.pem:/certs/ca-cert.pem:ro \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --ca-certificate /certs/ca-cert.pem
```

### Multiple Output Formats

Generate SARIF output for IDE integration:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --output sarif \
    --output-file-path /workspace/results.sarif
```

Generate JUnit XML for CI systems:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --output junitxml \
    --output-file-path /workspace/results.xml
```

### Terraform Plan Analysis

Enrich findings with Terraform plan data:
```bash
# First, generate your Terraform plan
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json

# Run the scan with plan enrichment
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --framework TERRAFORM \
    --deep-analysis \
    --repo-root-for-plan-enrichment /workspace
```

### Exclude Paths from Scan

Skip specific directories or files:
```bash
docker run --rm \
  --env-file cortex.env \
  -v "$(pwd)":/workspace \
  cortex-cli:ubuntu code scan \
    --directory /workspace \
    --branch main \
    --repo-id my-org/my-repo \
    --skip-path /workspace/node_modules \
    --skip-path /workspace/vendor \
    --skip-path /workspace/test
```

---

## 5. CI/CD Integration Examples

### GitHub Actions

```yaml
name: Cortex Security Scan
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
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
              --repo-id ${{ github.repository }} \
              --source GITHUB_ACTIONS \
              --create-repo-if-missing
```

### GitLab CI

```yaml
cortex-scan:
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_TLS_CERTDIR: ""
  script:
    - docker run --rm
        -e CORTEX_API_KEY=$CORTEX_API_KEY
        -e CORTEX_API_KEY_ID=$CORTEX_API_KEY_ID
        -e CORTEX_API_BASE_URL=$CORTEX_API_BASE_URL
        -v "$CI_PROJECT_DIR":/workspace
        cortex-cli:ubuntu code scan
          --directory /workspace
          --branch $CI_COMMIT_REF_NAME
          --repo-id $CI_PROJECT_PATH
          --source GITLAB_RUNNER
          --create-repo-if-missing
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    environment {
        CORTEX_API_KEY = credentials('cortex-api-key')
        CORTEX_API_KEY_ID = credentials('cortex-api-key-id')
        CORTEX_API_BASE_URL = credentials('cortex-api-url')
    }
    stages {
        stage('Security Scan') {
            steps {
                sh '''
                    docker run --rm \
                      -e CORTEX_API_KEY=$CORTEX_API_KEY \
                      -e CORTEX_API_KEY_ID=$CORTEX_API_KEY_ID \
                      -e CORTEX_API_BASE_URL=$CORTEX_API_BASE_URL \
                      -v "$WORKSPACE":/workspace \
                      cortex-cli:ubuntu code scan \
                        --directory /workspace \
                        --branch $GIT_BRANCH \
                        --repo-id $JOB_NAME \
                        --source JENKINS \
                        --create-repo-if-missing
                '''
            }
        }
    }
}
```

---

## 6. Shell Function for Convenience

Add this to your `~/.bashrc` or `~/.zshrc` for easier usage:

```bash
# Cortex CLI wrapper function
cortex() {
  local env_file="${CORTEX_ENV_FILE:-./cortex.env}"
  local docker_args="--rm"
  
  # Add env file if it exists
  if [[ -f "$env_file" ]]; then
    docker_args="$docker_args --env-file $env_file"
  fi
  
  # Add docker socket for image scans
  if [[ "$1" == "image" ]]; then
    docker_args="$docker_args -v /var/run/docker.sock:/var/run/docker.sock"
    docker_args="$docker_args --user $(id -u):$(id -g)"
    
    # Add docker group for socket access
    if getent group docker >/dev/null 2>&1; then
      docker_args="$docker_args --group-add $(getent group docker | cut -d: -f3)"
    fi
  fi
  
  docker run $docker_args \
    -v "$(pwd)":/workspace \
    cortex-cli:ubuntu "$@"
}

# Helper: Scan ECR image (handles login, pull, and scan)
cortex-ecr() {
  local image="$1"
  shift
  
  if [[ -z "$image" ]]; then
    echo "Usage: cortex-ecr <ecr-image-uri> [additional-args]"
    echo "Example: cortex-ecr 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest"
    return 1
  fi
  
  # Extract region from ECR URI
  local region=$(echo "$image" | grep -oP 'ecr\.\K[^.]+')
  
  # Login to ECR
  echo "Logging into ECR (region: $region)..."
  aws ecr get-login-password --region "$region" | \
    docker login --username AWS --password-stdin "$(echo $image | cut -d/ -f1)" || return 1
  
  # Pull the image
  echo "Pulling image..."
  docker pull "$image" || return 1
  
  # Scan
  echo "Scanning image..."
  cortex image scan "$image" "$@"
}
```

Usage:
```bash
# Code scan
cortex code scan --directory /workspace --branch main --repo-id my-org/my-repo

# Image scan (public or already-pulled images)
cortex image scan nginx:latest

# AWS ECR scan (handles login, pull, and scan in one command)
cortex-ecr 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest

# Check version
cortex --version
```

**Note:** For private registries, use `cortex-ecr` or pre-pull the image before scanning.

**Simple alias alternatives** (if you prefer one-liners):
```bash
# For code scans only
alias cortex-code='docker run --rm --env-file ${CORTEX_ENV_FILE:-./cortex.env} -v "$(pwd)":/workspace cortex-cli:ubuntu code scan'

# For image scans (assumes image is already pulled)
alias cortex-image='docker run --rm --env-file ${CORTEX_ENV_FILE:-./cortex.env} -v /var/run/docker.sock:/var/run/docker.sock --user $(id -u):$(id -g) --group-add $(getent group docker | cut -d: -f3) cortex-cli:ubuntu image scan'
```

---

## Troubleshooting

*   **File permissions**: If you encounter permission errors when scanning local files, match the container user to your host user:
    ```bash
    docker run --rm --user $(id -u):$(id -g) ...
    ```

*   **Docker socket permissions**: If image scan fails with permission denied:
    ```bash
    # Check your docker group ID
    getent group docker
    # Use --group-add with that GID, or run with --user root
    ```

*   **Hyperscan/Vectorscan**: The image uses Ubuntu 24.04 with `libvectorscan5`. A symlink (`libhyperscan.so.5` -> `libvectorscan.so.5`) is created for compatibility.

*   **Network issues**: For API scans, ensure the container can reach the target:
    - For local apps, use `--network host` or the host's actual IP
    - For proxy environments, set `HTTP_PROXY` and `HTTPS_PROXY` environment variables

*   **Output files**: When using `--output-file-path`, ensure the path is within a mounted volume to persist results.

*   **Timeout errors**: For large codebases or slow networks, increase the timeout:
    ```bash
    cortex-cli:ubuntu code scan --timeout 30m ...
    ```

*   **Environment file not found**: Ensure the path to `cortex.env` is correct, or use the full path:
    ```bash
    docker run --rm --env-file /full/path/to/cortex.env ...
    ```

*   **Private registry auth fails** ("exit status 2" or "no basic auth credentials"):
    
    Cortex CLI does not use standard Docker credentials for pulling images. Pre-pull the image on your host first:
    ```bash
    # Step 1: Login to your registry
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <registry>
    
    # Step 2: Pull the image
    docker pull <private-image>
    
    # Step 3: Scan (now works because image is local)
    docker run --rm --env-file cortex.env -v /var/run/docker.sock:/var/run/docker.sock \
      --user $(id -u):$(id -g) --group-add $(getent group docker | cut -d: -f3) \
      cortex-cli:ubuntu image scan <private-image>
    ```
