#!/usr/bin/env bash

# HOW IT WORKS:
# This script is designed to scan a specified Docker image for vulnerabilities using Palo Alto Networks' Cortex CLI.
# 1. It first checks for necessary prerequisites like a running Docker engine and Cortex API credentials.
# 2. It can optionally install the Cortex CLI and its dependencies if they are not present.
# 3. It ensures the target Docker image is available locally, pulling it from a registry if necessary.
# 4. It scans the image using 'cortexcli' and extracts the image_name and image_id from its output.
# 5. After the scan is processed, it uses the Cortex XQL API to query for vulnerability findings associated with the image's digest.
# 6. The script polls for the query results until they are ready.
# 7. Finally, it outputs the vulnerability data as a JSON object, either to the standard output or to a specified file.
#
# HOW TO USE IT:
# Make the script executable:
# chmod +x cortex-scan.sh
#
# Provide Cortex credentials either as environment variables or as command-line arguments.
#
# Example Usage:
#
# 1. Scan an image and print results to the console:
#    export CORTEX_API_URL="https://api.your-region.paloaltonetworks.com"
#    export CORTEX_API_KEY="your_api_key"
#    export CORTEX_API_KEY_ID="your_api_key_id"
#    ./cortex-scan.sh <your-docker-image-name>
#
# 2. Scan an image and save the results to a file:
#    ./cortex-scan.sh -u <cortex_url> -k <api_key> -i <key_id> -o findings.json <your-docker-image-name>
#
# 3. First-time setup to install the Cortex CLI and then scan:
#    # Note: This will run 'apt install' and requires root/sudo privileges.
#    ./cortex-scan.sh --install -u <cortex_url> -k <api_key> -i <key_id> <your-docker-image-name>
#
# ARGUMENTS:
#   <IMAGE_NAME>             (Required) The name of the Docker image to scan (e.g., 'ubuntu:latest').
#   -o, --output-file        Path to save the JSON output file. If not provided, output is printed to stdout.
#   -w, --wait               Seconds to wait for Cortex to process scan results before querying. Default: 600.
#   -t, --timeout            Timeout in seconds for the 'cortexcli image scan' command. Default: 360.
#   -u, --cortex-api-url     URL of the Cortex Cloud API.
#   -k, --cortex-api-key     API Key for Cortex authentication.
#   -i, --cortex-api-key-id  API Key ID for Cortex authentication.
#   --install                If set, the script will attempt to install cortexcli and its dependencies (jq, libhyperscan5).
#   -p, --cli-path           Directory where cortexcli is located or should be installed. Default: /usr/local/bin.
#   -v, --verbose            Enable verbose logging.

# Environment variables:
: '
    CORTEX_API_URL: URL of Cortex Cloud API 
    CORTEX_API_KEY: API Key of Cortex Cloud
    CORTEX_API_KEY_ID: API Key ID of Cortex Cloud
    IMAGE_NAME: Name of the image to scan
    OUTPUT_FILE: Name of the file to output
'
require_arg() {
    if [[ -z "$2" || "$2" == -* ]]; then
        echo "❌ Option $1 requires a value"
        exit 1
    fi
}

count_args=0
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -o|--output-file)
            require_arg "$1" "$2"
            OUTPUT_FILE="$2"
            shift
            ;;
        -w|--wait)
            require_arg "$1" "$2"
            WAIT="$2"
            shift
            ;;
        -t|--timeout)
            require_arg "$1" "$2"
            TIMEOUT="$2"
            shift
            ;;
        -u|--cortex-api-url)
            require_arg "$1" "$2"
            CORTEX_API_URL="$2"
            shift
            ;;
        -k|--cortex-api-key)
            require_arg "$1" "$2"
            CORTEX_API_KEY="$2"
            shift
            ;;
        -i|--cortex-api-key-id)
            require_arg "$1" "$2"
            CORTEX_API_KEY_ID="$2"
            shift
            ;;
        --install)
            INSTALL="true"
            ;;
        -v|--verbose)
            VERBOSE="true"
            ;;
        -p|--cli-path)
            require_arg "$1" "$2"
            CLI_PATH="$2"
            shift
            ;;
        *)
            count_args=$(($count_args + 1))
            [[ $1 == -* ]] && echo "❌ $1 is an invalid argument" && exit 1
            [[ $count_args -gt 1 ]] && echo "❌ Too many positional arguments" && exit 1
            IMAGE_NAME="$1"
      ;;
  esac
  shift
done

# Set Default values
[[ -z "$WAIT" ]] && WAIT="600"
[[ -z "$TIMEOUT" ]] && TIMEOUT="360"
[[ -z "$INSTALL" ]] && INSTALL="false"
[[ -z "$VERBOSE" ]] && VERBOSE="false"
[[ -z "$CLI_PATH" ]] && CLI_PATH="/usr/local/bin"

# Check for mandatory image
if [[ -z "$IMAGE_NAME" ]]; then
    echo "❌ Missing mandatory Image Name"
    exit 1
fi

# Check if docker engine is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running. Please start the Docker daemon."
  exit 1
fi

# Check if there are missing credentials
if [[ -z "$CORTEX_API_URL" || -z "$CORTEX_API_KEY" || -z "$CORTEX_API_KEY_ID"  ]]; then
    echo "❌ Missing credentials from environment or arguments"
    exit 1    
fi

# Install CortexCLI
if [[ "$INSTALL" == "true" ]]; then
    echo "Installing dependencies"
    apt install libhyperscan5 jq -y
    if [[ "$?" -ne 0 ]]; then 
        echo "❌ Dependencies could not be installed"
        exit 1
    fi
    echo "✅ Dependencies installed successfully!"
    echo "Downloading CortexCLI"
    crtx_resp=$(curl -s -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" -H "Authorization: ${CORTEX_API_KEY}" "${CORTEX_API_URL}/public_api/v1/unified-cli/releases/download-link?os=linux&architecture=amd64")
    [[ "$?" -ne 0 ]] && echo "❌ Failed to retrieve CortexCLI download link" && exit 1
    crtx_url=$(echo "$crtx_resp" | jq -r ".signed_url")
    if [[ -z "$crtx_url" || "$crtx_url" == "null" ]]; then
        echo "❌ Failed to extract download URL from API response"
        [[ "$VERBOSE" == "true" ]] && echo "API Response: $crtx_resp"
        exit 1
    fi
    curl -s -o cortexcli "$crtx_url"
    [[ "$?" -ne 0 ]] && echo "❌ Failed to download CortexCLI from signed URL" && exit 1
    chmod +x cortexcli
    [[ "$?" -ne 0 ]] && echo "❌ Failed to make CortexCLI executable" && exit 1
    mv cortexcli "$CLI_PATH/"
    [[ "$?" -ne 0 ]] && echo "❌ Failed to move CortexCLI to $CLI_PATH (check permissions)" && exit 1
    echo "✅ CortexCLI downloaded successfully!"
fi

"$CLI_PATH/cortexcli" --version
if [[ "$?" -ne 0 ]]; then
    echo "❌ Missing CortexCLI"
    exit 1
fi
echo "✅ CortexCLI found"

# Check if the image exists locally
if [[ "$(docker images -q "$IMAGE_NAME" 2> /dev/null)" == "" ]]; then
    echo "Image '$IMAGE_NAME' does NOT exist locally. Pulling image"
  
    # Try to pull the image
    if ! docker pull "$IMAGE_NAME"; then
        echo "❌ Critical Error: Failed to pull image '$IMAGE_NAME'. Please check the image name or your network connection."
        exit 1
    else
        echo "✅ Success: Image '$IMAGE_NAME' has been pulled."
    fi

else
  echo "✅ Image '$IMAGE_NAME' found locally."
fi

# Scan the image with CortexCLI
echo "Starting scan of '$IMAGE_NAME' with CortexCLI..."
scan_output=$("$CLI_PATH/cortexcli" --api-base-url "$CORTEX_API_URL" --api-key "$CORTEX_API_KEY" --api-key-id "$CORTEX_API_KEY_ID" --soft-fail image scan --timeout "$TIMEOUT" --name "$IMAGE_NAME" "$IMAGE_NAME" 2>&1)
exit_code="$?"
[[ "$VERBOSE" == "true" ]] && echo "Exit Code: $exit_code"
[[ "$VERBOSE" == "true" ]] && echo "Scan output:" && echo "$scan_output"

# Exit code 0 = passed, 1 = issues found (success), 2 = scan failed
if [[ "$exit_code" -eq 2 ]]; then
    echo "❌ Failed to scan image with cortexcli (exit code: 2)"
    echo "$scan_output"
    if [[ "$VERBOSE" == "true" ]] && [[ -d "$HOME/.cortexcli/logs" ]]; then
        latest_log=$(ls -1rt "$HOME/.cortexcli/logs" 2>/dev/null | tail -n1)
        if [[ -n "$latest_log" ]]; then
            echo "Recent errors from cortexcli logs:"
            grep "ERROR" "$HOME/.cortexcli/logs/$latest_log" 2>/dev/null || echo "No ERROR entries found in logs"
        fi
    fi
    exit 1
fi

echo "✅ Scan completed successfully"

# Extract image_name and image_id from cortexcli output
# Output format: "Scans result for image [image_name] - [image_id]"
scan_result_line=$(echo "$scan_output" | grep -m1 'Scans result for image')
if [[ -z "$scan_result_line" ]]; then
    echo "❌ Could not find 'Scans result for image' line in cortexcli output"
    echo "Output was:"
    echo "$scan_output"
    exit 1
fi

image_id=$(echo "$scan_result_line" | sed 's/.*- \(sha256:[a-fA-F0-9]\{64\}\).*/\1/')
image_name=$(echo "$scan_result_line" | sed 's/Scans result for image \(.*\) - sha256:[a-fA-F0-9]\{64\}.*/\1/')

if [[ -z "$image_id" || ! "$image_id" =~ ^sha256:[a-fA-F0-9]{64}$ ]]; then
    echo "❌ Failed to extract image_id from cortexcli output. Line was:"
    echo "$scan_result_line"
    exit 1
fi
if [[ -z "$image_name" ]]; then
    echo "❌ Failed to extract image_name from cortexcli output. Line was:"
    echo "$scan_result_line"
    exit 1
fi

echo "Extracted image_name: $image_name"
echo "Extracted image_id: $image_id"

# Wait for Cortex Cloud to process the information
echo "Waiting for Cortex Cloud to process the information..."
sleep "$WAIT"


# Execute API call to start the query
echo "Obtaining findings of image $IMAGE_NAME..."
# Build exact UTC time bounds for XQL timeframe.
if date -u -v-1d "+%Y-%m-%d %H:%M:%S +0000" >/dev/null 2>&1; then
    start_time_utc=$(date -u -v-7d "+%Y-%m-%d %H:%M:%S +0000")
    end_time_utc=$(date -u -v+2d "+%Y-%m-%d %H:%M:%S +0000")
else
    start_time_utc=$(date -u -d "7 days ago" "+%Y-%m-%d %H:%M:%S +0000")
    end_time_utc=$(date -u -d "2 days" "+%Y-%m-%d %H:%M:%S +0000")
fi

if [[ -z "$start_time_utc" || -z "$end_time_utc" ]]; then
    echo "❌ Failed to compute UTC timeframe bounds for XQL query."
    exit 1
fi

[[ "$VERBOSE" == "true" ]] && echo "XQL timeframe UTC: $start_time_utc -> $end_time_utc"

xql_query=$(cat <<XQLEOF
config timeframe between "$start_time_utc" and "$end_time_utc"
| dataset = uvm_findings
| join type=inner (
    dataset = asset_inventory
    | filter xdm.asset.type.category = "Container Image"
    | filter xdm.asset.type.id = "BUILD_IMAGE"
    | alter image_identifier = json_extract_scalar(xdm.asset.normalized_fields, "\$['xdm.image.identifier']")
    | filter image_identifier = "$image_id"
    | sort desc xdm.asset.last_observed
    | limit 1
    | fields xdm.asset.id as asset_id
  ) as inv inv.asset_id = asset_id
| dedup vulnerability_id, package_purl
XQLEOF
)
start_payload=$(jq -n --arg query "$xql_query" '{request_data: {query: $query}}')
echo "XQL query:"
echo "$xql_query"

start_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: ${CORTEX_API_KEY}" -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" "${CORTEX_API_URL}/public_api/v1/xql/start_xql_query" -d "$start_payload")
query_id=$(echo "$start_response" | jq -r '.reply')

if [[ "$query_id" == "null" || -z "$query_id" ]]; then
    echo "❌ Failed to start XQL query. Response details:"
    echo "$start_response"
    exit 1
fi

echo "XQL Query started successfully. Query ID: ${query_id}"


# Define initial status
echo "Retrieving results for Query ID: ${query_id}. Waiting for completion (pending_flag=true)..."
status="PENDING"

results_payload=$(jq -n --arg qid "$query_id" '{
    request_data: {
        query_id: $qid,
        pending_flag: true,
        format: "json"
    }
}')

poll_attempts=0
max_poll_attempts=60
while [[ "$status" == "PENDING" ]]; do
    poll_attempts=$((poll_attempts + 1))
    if [[ "$poll_attempts" -gt "$max_poll_attempts" ]]; then
        echo "❌ Timed out waiting for XQL query results after $((max_poll_attempts * 10)) seconds"
        exit 1
    fi
    results_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: ${CORTEX_API_KEY}" -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" "${CORTEX_API_URL}/public_api/v1/xql/get_query_results" -d "$results_payload")
    status=$(echo "$results_response" | jq -r '.reply.status')
    sleep 10
done

echo "Status of the query: $status"
# Print the full response for troubleshooting
if [[ "$status" == "SUCCESS" ]]; then
    echo "✅ Status of the query: $status"
    
    if [[ -z "$OUTPUT_FILE" ]]; then
        echo "$results_response" | jq --arg img "$image_name" '.reply.results.data | map(.image_name = $img)'
    else
        echo "$results_response" | jq --arg img "$image_name" '.reply.results.data | map(.image_name = $img)' > "$OUTPUT_FILE"
    fi
else
    echo "❌ Status of the query: $status"
    echo "Results:"
    echo "$results_response" | jq .
    exit 1
fi