# Cortex XDR 4.x Documentation

**Confidential - Copyright © Palo Alto Networks**

## Table of Contents

1. [Cortex CLI](#1-cortex-cli)
    1.1. [Connect Cortex CLI](#11-connect-cortex-cli)
    1.2. [Cortex CLI common command line reference guide](#12-cortex-cli-common-command-line-reference-guide)
2. [Cortex CLI for API Security](#2-cortex-cli-for-api-security)
    2.1. [Cortex CLI API Security command line reference guide](#21-cortex-cli-api-security-command-line-reference-guide)
3. [Cortex CLI for Cloud Workload Protection](#3-cortex-cli-for-cloud-workload-protection)
    3.1. [Cloud Workload Protection command line reference](#31-cloud-workload-protection-command-line-reference)
4. [Cortex CLI for Cortex Cloud Application Security](#4-cortex-cli-for-cortex-cloud-application-security)
    4.1. [Cortex CLI usage for Cortex Cloud Application Security](#41-cortex-cli-usage-for-cortex-cloud-application-security)
    4.2. [CLI pipeline code snippets](#42-cli-pipeline-code-snippets)
    4.3. [Cortex CLI Cortex Cloud Application Security command line reference](#43-cortex-cli-cortex-cloud-application-security-command-line-reference)

---

## 1. Cortex CLI

The Cortex CLI provides a unified command interface to efficiently scan your Cloud Workload Protection (CWP), API Security, and Cortex Cloud Application Security environments with a single installation, enabling you to seamlessly integrate security checks into your development process.

### User roles and permissions

Cortex CLI provides a role-based access control mechanism that controls user permissions and access to the CLI features and functionalities. Permissions for CLI scans are based on the associated API key. Each API key can be associated with a specific role, regardless of the user who generated it.

*   **Preconfigured roles:**
    *   **CLI Role:** Grants permission to onboard and install the CLI. Enables uploading scan results to the tenant and provides management capabilities. Includes CLI Read Only Role permissions.
    *   **CLI Read Only Role:** Grants permission to run the CLI and view output in the CLI. Scan results are not uploaded to the tenant.
        > **NOTE:** The CLI Read Only Role is not supported for CWP as the system does not support offline mode.

*   **Custom roles:** You can create custom roles that include CLI permissions.

### 1.1 Connect Cortex CLI

Connect Cortex CLI to scan supported Cortex Cloud modules and gain insights into your security posture.

#### System requirements

*   **macOS** (Intel Core i7, such as Sequoia): Must install `vectorscan` via Homebrew: `brew install vectorscan`
*   **RHEL 8.10 and Red Hat UBI9**: Must install `patchelf` and `zstd`.
*   **Ubuntu 20**: Requires the `prefetch` utility.
*   **Ubuntu (for linux-amd64)**: Requires `libhyperscan5`. Install via: `sudo apt install libhyperscan5`
*   **Linux for AppSec Module**:
    *   RHEL 10: Kernel 6.12, glibc 2.39
    *   Debian 12: Kernel 6.1.27, glibc 2.36
    *   Ubuntu: 18.04, 20.04, 22.04, 24.04 (specific kernel/glibc versions apply)
*   **Windows**: AMD 64 and ARM 64

**For cURL-based downloads:** `curl`, `jq`.

#### Download and run the Cortex CLI

1.  **On your tenant:**
    *   Navigate to **Settings** → **Data Sources** → **+ Data Source**.
    *   Search for **Cortex CLI** → **Connect**.
2.  **Configure:**
    *   Select your operating system.
    *   Copy the download command and run it in your terminal.
3.  **Authenticate:**
    *   Generate an API key (Recommended: **CLI Role**).
    *   Copy the **API Key ID** and **API Key**.
    *   Download the CLI tool to your system.

**Manual Download Steps:**

1.  **Download:**
    ```bash
    curl -k -u $CORTEX_API_ID::$CORTEX_API_KEY --output ./cortexcli $CORTEX_FQDN/api/v2/remote-li/{version}/{platform}/artifacts
    ```
2.  **Make Executable:**
    ```bash
    chmod +x cortexcli
    ```
3.  **Verify:**
    ```bash
    cortexcli -v
    ```

#### Authentication

*   **Command-line flags:**
    ```bash
    --api-base-url: [$CORTEX_API_BASE_URL]
    --api-key: [$CORTEX_API_KEY]
    --api-key-id: [$CORTEX_KEY_ID]
    ```
*   **Environment configuration file:** Create `cortex.env`:
    ```
    CORTEX_API_KEY_ID: <api key id>
    CORTEX_API_KEY: <secret>
    CORTEX_API_BASE_URL: <tenant URL>
    ```

#### Usage

To execute a Cortex CLI scan:
```bash
cortexcli [global flags] [module name] scan [module flags]
```

*   **Global flags:** `--api-base-url`, `--api-key`, `--api-key-id`
*   **Module name:** `api` (API Security), `image` (CWP), `code scan` (AppSec)

---

### 1.2 Cortex CLI common command line reference guide

Common command line flags used to manage Cortex Cloud Application Security, CWP, and API Security modules.

| Command | Description |
| :--- | :--- |
| `--api-base-url` | The public facing API URL. `[$CORTEX_API_BASE_URL]` |
| `--api-key` | The API key used for authorization. `[$CORTEX_API_KEY]` |
| `--api-key-id` | The API key ID. `[$CORTEX_API_KEY_ID]` |
| `--soft-fail` | Reports errors but does not trigger a failing condition (exit code 0). `[$CORTEX_SOFT_FAIL]` |
| `--log-level` | Set the logging level (INFO, WARNING, ERROR) for Stdout. |
| `--http-proxy` | The HTTP proxy server URL. `[$HTTP_PROXY]` |
| `--help` | Show help options. |
| `--version` | Retrieves the version of the Cortex CLI. |

---

## 2. Cortex CLI for API Security

Evaluates APIs for vulnerabilities and misconfigurations using fuzzing techniques.

**Prerequisites:**
*   Required user permissions.
*   Cortex CLI installed.
*   Application exposes APIs and provides an OpenAPI Specification file.
*   Java v11 or above installed.

### Authentication File Schema

Example `auth-file.yaml`:

```yaml
# Headers
type: headers
creds:
  name: <header name>
  value: <header value>

# Basic Auth
type: basic
creds:
  username: {USERNAME}
  password: {PASSWORD}

# API Keys
type: headers
creds:
  name: x-api-key
  value: {API key}

# Bearer Token
type: headers
creds:
  name: Authorization
  value: Bearer {BEARER_TOKEN}
```

### Running API Security scans

```bash
./cortexcli --log-level <ERROR LEVEL> --api-base-url <API URL> \
  --api-key <API KEY> --auth-id 1 api scan \
  --api-spec-file <OPENAPI SPEC LOCATION> \
  --scanned-app-url <BASE URL OF SCANNED APP> \
  --java-location <JAVA BIN LOCATION>
```

### 2.1 Cortex CLI API Security command line reference guide

| Value | Command |
| :--- | :--- |
| `--scanned-app-url` (string) | Base URL of the app to scan (required). |
| `--api-spec-file` (string) | Path to the API specification file (required). |
| `--api-spec-type` (string) | Type of the API specification (default `openapi`). |
| `--auth-file` (string) | Path to the authentication file (optional). |
| `--concurrency` (int) | Concurrency limit for scan requests (default 5). |
| `--java-location` (string) | Path to the Java (version >= 11) binary file. |
| `--no-publish` (boolean) | Avoid publishing results to Cortex. |
| `--output-file` (string) | Output path for the report file (optional). |
| `--timeout` (int) | Scan timeout in seconds (default 300). |
| `--zap-port` (int) | Listening port to be used by ZAP (default 35391). |

---

## 3. Cortex CLI for Cloud Workload Protection

Integrate CWP scans for secrets, vulnerabilities, and malware during your CI process. Leverages SBOM analysis.

**Prerequisites:**
*   Required user permissions.
*   Cortex CLI installed.
*   Java version 11 or above.

### Run CWP security scans

```bash
./cortexcli --api-base-url <API URL> --api-key <API KEY> \
  --api-key-id <API KEY ID> image scan <archive file of container image>
```

### Image scans

*   **Docker daemon integration (default):**
    ```bash
    cortexcli image scan [command options]
    ```
    Use `--docker-host` to specify the socket path (default: `unix:///var/run/docker.sock`).

*   **Scan a .tar archive:**
    ```bash
    sudo ./cortexcli --api-base-url "${xdr_url}" ... image scan --archive ubuntu.tar
    ```
    Must specify `--archive true` (implied by just `--archive` if boolean parsing allows, or explicitly).

### Generate SBOM

Command: `cortexcli image sbom`

```bash
sudo ./cortexcli ... image sbom <image-name>
```

### 3.1 Cloud Workload Protection command line reference

| Command | Description |
| :--- | :--- |
| `--image scan` | Scans a container image archive. |
| `--ci-pipeline-id` value | The CI pipeline identifier. |
| `--ci-build-id` value | The CI build identifier. |
| `--timeout` value | Timeout (seconds) (default: 60). |
| `--output-format` value | Output format: `human-readable`, `json`. |
| `--archive-format` value | Archive format: `docker-archive`, `oci-archive`. |
| `--name` value | Name assigned to the image. |
| `--docker-host` <path> | Path to the Docker socket. |
| `--docker-address` | Path to Docker daemon socket (default `unix:///var/run/docker.sock`). |
| `--archive` | Specifies that the image scan should use an archive file. |

---

## 4. Cortex CLI for Cortex Cloud Application Security

Scans for **Secrets**, **Infrastructure-as-Code (IaC)**, and **Software Composition Analysis (SCA)**. Supports integration with CI tools.

**Prerequisites:**
*   **Node.js v22** installed (for the binary).
*   **Linux OS:** GLIBC 2.35 or greater.
*   **Permissions:** Required user permissions.

### Proxy Configuration
*   Environment variables: `HTTP_PROXY`, `HTTPS_PROXY`.
*   **CA Certificate:** Use `--ca-certificate` flag or `$CORTEX_CA_CERTIFICATE` env variable.
*   **Skip verification:** Use `--no-cert-verify` flag or `$CORTEX_NO_CERT_VERIFY`.

### 4.1 Cortex CLI usage for Cortex Cloud Application Security

```bash
cortexcli --api-base-url <API URL> --api-key <API KEY> --api-key-id <KEY ID> \
  code scan --directory {{DIRECTORY}} --branch main \
  --repo-id organization/repo-name --output json --output-file-path ./output.json
```

**Common outputs:**
*   Standard output (stdout)
*   JSON output (`--output json --output-file-path ...`)

### 4.2 CLI pipeline code snippets

Integrate into CI/CD pipelines (AWS CodeBuild, Azure Pipelines, Bitbucket, CircleCI, GitHub Actions, GitLab Runner, Jenkins).

**Example: GitHub Actions (AMD architecture)**

```yaml
name: Cortex CLI Code Scan
on:
  push:
    branches: [ main ]
env:
  CORTEX_API_KEY: ${{secrets.CORTEX_API_KEY}}
  CORTEX_API_KEY_ID: ${{secrets.CORTEX_API_KEY_ID}}
  CORTEX_API_URL: <your_cortex_api_url>
jobs:
  cortex-code-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Download cortexcli
        run: | 
          # ... (curl command to download cli) ...
      - name: Run Cortex CLI Code Scan
        run: |
          ./cortexcli \
            --api-base-url "${CORTEX_API_URL}" \
            --api-key "${CORTEX_API_KEY}" \
            --api-key-id "${CORTEX_API_KEY_ID}" \
            code scan \
            --directory "${{github.workspace}}" \
            --repo-id "${{github.repository}}" \
            --branch "${{github.ref_name}}" \
            --source "GITHUB_ACTIONS" \
            --create-repo-if-missing
```

*(See PDF for full snippets for all platforms and architectures)*

### 4.3 Cortex CLI Cortex Cloud Application Security command line reference

**IMPORTANT:** Only supports single occurrences of each flag.

| Command/Variable | Description |
| :--- | :--- |
| `--source` | Source of execution (e.g., CLI, JENKINS, GITHUB_ACTIONS). |
| `--repo-id` | **Required for upload mode.** Identity string (`owner/name`). Must not end with `.config`, `.log`, or `.ini`. |
| `--branch` | **Required for upload mode.** Selected branch. |
| `--directory` | **Required.** Directory path to scan. Cannot use with `--file`. |
| `--file` | File path to scan. Cannot use with `--directory`. |
| `--var-file` | Variable files to load (.tfvars). |
| `--framework` | Filter scan to specific frameworks (e.g., TERRAFORM, SECRETS, SCA). |
| `--skip-framework` | Filter scan to skip specific frameworks. |
| `--ca-certificate` | CA Certificate to use. |
| `--no-cert-verify` | Disables TLS/SSL verification. |
| `--summary-position` | Position for displaying summary. |
| `--upload-mode` | `upload` (default), `no-upload`, `no-code`. |
| `--external-modules-download-path` | Directory for external modules. |
| `--output` | Formats: `cli`, `json`, `spdx`, `junitxml`, `sarif`, `cyclonedx`, `cyclonedx_json`. |
| `--output-file-path` | Path for scan result file. |
| `--deep-analysis` | Enable/disable deep analysis of Terraform plans. |
| `--repo-root-for-plan-enrichment` | Enriches Terraform plan findings. |
| `--skip-path` | Path (file or directory) to skip. |
| `--create-repo-if-missing` | Automatically create repository if missing. |
| `--compact` | Do not display code blocks in output. |
| `--no-fail-on-crash` | Prevents application from failing the pipeline on scanner failure. |
| `CORTEX_APPSEC_VALIDATE_SECRETS` | Set to `true` to enable secret validation. |
| `--timeout` | Maximum time to wait for local scan processes (default 15m). |
