#!/bin/bash

# Script to start Keycloak service using Docker Compose

# Exit on any error
set -e

# Define paths and config
KEYCLOAK_COMPOSE_FILE="./compose.yml"
KEYCLOAK_ENV_FILE="./env.d/.env"
KEYCLOAK_DATA_DIR="./keycloak_data"
REALM_IMPORT_DIR="./realms"
SSL_EXTRACT_SCRIPT="./test-ssl-extraction.sh"
SSL_CERT_DIR="./ssl"
SSL_CERT_FILE="$SSL_CERT_DIR/tls.crt"
SSL_KEY_FILE="$SSL_CERT_DIR/tls.key"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate a local self-signed certificate for non-cPanel environments
generate_self_signed_cert() {
    local cert_file="$1"
    local key_file="$2"
    local cert_cn="${KEYCLOAK_HOSTNAME:-localhost}"

    echo -e "${YELLOW}Generating self-signed SSL certificate for ${cert_cn}...${NC}"
    mkdir -p "$SSL_CERT_DIR"

    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -days 365 \
        -subj "/CN=${cert_cn}" >/dev/null 2>&1 || return 1

    chmod 600 "$key_file" || true
    echo -e "${GREEN}Self-signed certificate created in $SSL_CERT_DIR${NC}"
    return 0
}

# Function to check certificate validity
check_cert_validity() {
    local cert_file="$1"
    local key_file="$2"

    # Check if files exist
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        echo -e "${RED}Certificate or key file missing in $SSL_CERT_DIR${NC}"
        return 1
    fi

    # Check if certificate and key match
    cert_md5=$(openssl x509 -noout -modulus -in "$cert_file" 2>/dev/null | openssl md5 2>/dev/null)
    key_md5=$(openssl rsa -noout -modulus -in "$key_file" 2>/dev/null | openssl md5 2>/dev/null)
    if [ "$cert_md5" != "$key_md5" ]; then
        echo -e "${RED}Certificate and private key do not match${NC}"
        return 1
    fi

    # Check if certificate is expired or near expiry (within 7 days)
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$expiry_date" ]; then
        echo -e "${RED}Unable to read certificate expiry date${NC}"
        return 1
    fi

    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
    current_epoch=$(date +%s)
    seven_days=$((7 * 24 * 60 * 60))

    if [ $((expiry_epoch - current_epoch)) -lt $seven_days ]; then
        echo -e "${YELLOW}Certificate is expired or will expire within 7 days${NC}"
        return 1
    fi

    echo -e "${GREEN}Existing certificate and key are valid${NC}"
    return 0
}

# Load environment variables
if [ ! -f "$KEYCLOAK_ENV_FILE" ]; then
    error_exit "Keycloak .env file ($KEYCLOAK_ENV_FILE) not found."
fi

set -a
. "$KEYCLOAK_ENV_FILE"
set +a

# Check if Docker and Docker Compose are installed
if ! command_exists docker; then
    error_exit "Docker is not installed. Please install Docker and try again."
fi
if ! command_exists docker-compose; then
    error_exit "Docker Compose is not installed. Please install Docker Compose and try again."
fi
if ! command_exists openssl; then
    error_exit "OpenSSL is not installed. Please install OpenSSL and try again."
fi

# Check if Docker Compose file exists
if [ ! -f "$KEYCLOAK_COMPOSE_FILE" ]; then
    error_exit "Keycloak Compose file ($KEYCLOAK_COMPOSE_FILE) not found."
fi

# Check for existing SSL certificates
echo -e "${YELLOW}Checking for existing SSL certificates...${NC}"
if ! check_cert_validity "$SSL_CERT_FILE" "$SSL_KEY_FILE"; then
    echo -e "${YELLOW}Running SSL certificate extraction...${NC}"
    if [ -f "$SSL_EXTRACT_SCRIPT" ]; then
        if ! bash "$SSL_EXTRACT_SCRIPT"; then
            echo -e "${YELLOW}SSL extraction failed (likely non-cPanel host). Falling back to self-signed certificate.${NC}"
            generate_self_signed_cert "$SSL_CERT_FILE" "$SSL_KEY_FILE" || error_exit "Failed to generate self-signed SSL certificates."
        fi
    else
        echo -e "${YELLOW}SSL extraction script not found. Falling back to self-signed certificate.${NC}"
        generate_self_signed_cert "$SSL_CERT_FILE" "$SSL_KEY_FILE" || error_exit "Failed to generate self-signed SSL certificates."
    fi

    # Verify extracted certificates
    if ! check_cert_validity "$SSL_CERT_FILE" "$SSL_KEY_FILE"; then
        error_exit "Extracted SSL certificate or key is invalid."
    fi
else
    echo -e "${GREEN}Using existing valid certificates in $SSL_CERT_DIR${NC}"
fi

# Create suite_net if it doesn't exist
echo -e "${YELLOW}Checking for suite_net network...${NC}"
if ! docker network ls | grep -q "suite_net"; then
    echo "Creating suite_net network..."
    docker network create suite_net || error_exit "Failed to create suite_net network."
    echo -e "${GREEN}suite_net network created successfully.${NC}"
else
    echo -e "${GREEN}suite_net network already exists.${NC}"
fi

# Prepare necessary directories
echo -e "${YELLOW}Setting up data and realm import directories...${NC}"
mkdir -p "$KEYCLOAK_DATA_DIR" "$REALM_IMPORT_DIR" "$SSL_CERT_DIR"
sudo chown -R 1000:1000 "$KEYCLOAK_DATA_DIR" "$SSL_CERT_DIR"
echo -e "${GREEN}Directories ready.${NC}"

# Start Keycloak
echo -e "${YELLOW}Starting Keycloak service...${NC}"
docker-compose -f "$KEYCLOAK_COMPOSE_FILE" up -d || error_exit "Failed to start Keycloak service."

# Wait for Keycloak to become healthy
echo -e "${YELLOW}Waiting for Keycloak to become healthy...${NC}"
until docker inspect grow24_keycloak --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; do
    sleep 3
    status=$(docker inspect grow24_keycloak --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    echo "Keycloak health status: $status"
    if [ "$(docker inspect grow24_keycloak --format='{{.State.Status}}' 2>/dev/null)" != "running" ]; then
        error_exit "Keycloak container is not running. Check logs with 'docker logs grow24_keycloak'."
    fi
done

echo -e "${GREEN}Keycloak is healthy and running on https://localhost:${KEYCLOAK_PORT}${NC}"
echo "Keycloak logs: docker logs grow24_keycloak"