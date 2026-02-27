#!/usr/bin/bash

# HOW IT WORKS:
# This script is designed to scan a specified Docker image for vulnerabilities using Palo Alto Networks' Cortex CLI.
# 1. It first checks for necessary prerequisites like a running Docker engine and Cortex API credentials.
# 2. It can optionally install the Cortex CLI and its dependencies if they are not present.
# 3. It ensures the target Docker image is available locally, pulling it from a registry if necessary.
# 4. It checks if the image has already been scanned and exists in the Cortex cloud backend.
# 5. If the image is new, it initiates a scan using 'cortexcli'.
# 6. After the scan is processed (or if the image already existed), it uses the Cortex XQL API to query for vulnerability findings associated with the image's digest.
# 7. The script polls for the query results until they are ready.
# 8. Finally, it outputs the vulnerability data as a JSON object, either to the standard output or to a specified file.
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
count_args=0
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -o|--output-file)
            OUTPUT_FILE="$2"
            shift
            ;;
        -w|--wait)
            WAIT="$2"
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift
            ;;
        -u|--cortex-api-url)
            CORTEX_API_URL="$2"
            shift
            ;;
        -k|--cortex-api-key)
            CORTEX_API_KEY="$2"
            shift
            ;;
        -i|--cortex-api-key-id)
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
            CLI_PATH="$2"
            shift
            ;;
        *)
            
            count_args=$(($count_args + 1))
            [[ $1 == -* ]] && echo "$1 is invalid argument" && exit 1
            [[ $count_args -gt 1 ]] && echo "Too many arguments" && exit 1
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

# Check if there are missing credentials credentials
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
    crtx_resp=$(curl -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" -H "Authorization: ${CORTEX_API_KEY}" "${CORTEX_API_URL}/public_api/v1/unified-cli/releases/download-link?os=linux&architecture=amd64")
    [[ "$?" -ne 0 ]] && echo "❌ Failed to Download CortexCLI" && exit 1
    crtx_url=$(echo $crtx_resp | jq -r ".signed_url")
    curl -o cortexcli $crtx_url
    [[ "$?" -ne 0 ]] && echo "❌ Failed to Download CortexCLI" && exit 1
    chmod +x cortexcli
    mv cortexcli "$CLI_PATH/"
    [[ "$?" -ne 0 ]] && echo "❌ Failed to Move CortexCLI to $CLI_PATH" && exit 1
    echo "✅ CortexCLI downloaded successfully!"
fi

$CLI_PATH/cortexcli --version
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

# Search if the image exists in Cortex Cloud
image_id=$(docker inspect $IMAGE_NAME --format='{{.Id}}')
echo "Searching if the image '$IMAGE_NAME' exists in Cortex Cloud. Digest: $image_id..."
search_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: ${CORTEX_API_KEY}" -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" "${CORTEX_API_URL}/public_api/v1/assets" -d '
    {
        "request_data": {
            "filters": {
                "AND": [
                    {
                        "SEARCH_FIELD": "xdm.asset.name",
                        "SEARCH_TYPE": "EQ",
                        "SEARCH_VALUE": "'$image_id'"
                    }  
                ]
            },
            "search_from": 0,
            "search_to": 0
        
        }
    }')

asset_info=$(echo $search_response | jq -r '.reply.data[]')

# If the asset does not exist then perform the scan
if [[ -z "$asset_info" ]]; then
    # Start CortexCLI image scan
    echo "Image '$IMAGE_NAME' does not exist in Cortex Cloud"
    echo "Starting scan with CortexCLI"
    $CLI_PATH/cortexcli --api-base-url $CORTEX_API_URL --api-key $CORTEX_API_KEY --api-key-id $CORTEX_API_KEY_ID --soft-fail image scan --timeout "$TIMEOUT" --name "$IMAGE_NAME" "$IMAGE_NAME"
    exit_code="$?"
    [[ "$VERBOSE" == "true" ]] && echo "Exit Code: $exit_code"

    if [[ "$exit_code" -eq 2 ]]; then
        echo "❌ Failed to get results from cortexcli"
        [[ "$VERBOSE" == "true" ]] && cat "$HOME/.cortexcli/logs/$(ls -1rt $HOME/.cortexcli/logs | tail -n1)" | grep "ERROR"
        exit 1
    fi

    # Extract image Id
    image_id=$(echo $results | grep -oP '(?<="image_id":")[^"]*')

    # Wait for Cortex Cloud to process the information
    echo "Waiting for Cortex Cloud to process the information..."
    sleep "$WAIT"
else
    echo "✅ Image '$IMAGE_NAME' found in Cortex Cloud."
fi


# Execute API call to start the query
echo "Obtaining findings of image $IMAGE_NAME..."
start_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: ${CORTEX_API_KEY}" -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" "${CORTEX_API_URL}/public_api/v1/xql/start_xql_query" -d '
    {
        "request_data": {
            "query": "config timeframe between \"-7d\" and \"+1d\" | dataset = uvm_findings | filter asset_name = \"'$image_id'\" | dedup vulnerability_id, package_purl"
        }
    }')
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

while [[ "$status" == "PENDING" ]]; do
    # Execute API call to get results
    results_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: ${CORTEX_API_KEY}" -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" "${CORTEX_API_URL}/public_api/v1/xql/get_query_results" -d '
        {
            "request_data": {
                "query_id": "'$query_id'", 
                "pending_flag": true, 
                "format": "json"
            }
        }')
    status=$(echo "$results_response" | jq -r '.reply.status')
    sleep 10
done

echo "Status of the query: $status"
# Print the full response for troubleshooting
if [[ "$status" == "SUCCESS" ]]; then
    echo "✅ Status of the query: $status"
    
    if [[ -z "$OUTPUT_FILE" ]]; then
        echo "$results_response" | jq '.reply.results.data' | jq 'map(.image_name = "'$IMAGE_NAME'")'
    else
        echo "$results_response" | jq '.reply.results.data' | jq 'map(.image_name = "'$IMAGE_NAME'")' > $OUTPUT_FILE
    fi
else
    echo "❌ Status of the query: $status"
    echo "Results:"
    echo "$results_response" | jq .
    exit 1
fi
