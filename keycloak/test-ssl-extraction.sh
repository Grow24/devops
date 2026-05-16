#!/bin/bash

# Script to extract SSL certificate and private key from cPanel
DOMAIN="keycloak.intelligentsalesman.com"
SSL_CERT_DIR="./ssl"
CPANEL_SSL_DIR="/var/cpanel/ssl/domain_tls/${DOMAIN}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Extracting SSL certificate and private key for $DOMAIN${NC}"

# Create SSL directory
mkdir -p "$SSL_CERT_DIR"

# Check if cPanel SSL directory exists
if [ -d "$CPANEL_SSL_DIR" ]; then
    echo -e "${GREEN}Found cPanel SSL directory: $CPANEL_SSL_DIR${NC}"

    # Check for combined certificate file
    if [ -f "$CPANEL_SSL_DIR/combined" ]; then
        echo -e "${GREEN}Found combined certificate file${NC}"

        # Extract certificate (including intermediate certificates)
        echo -e "${YELLOW}Extracting certificate...${NC}"
        awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$CPANEL_SSL_DIR/combined" > "$SSL_CERT_DIR/tls.crt"

        # Extract private key (handle RSA PRIVATE KEY format)
        echo -e "${YELLOW}Extracting private key...${NC}"
        awk '/BEGIN RSA PRIVATE KEY/,/END RSA PRIVATE KEY/' "$CPANEL_SSL_DIR/combined" > "$SSL_CERT_DIR/tls.key"

        # Check if extraction was successful
        if [ -s "$SSL_CERT_DIR/tls.crt" ]; then
            echo -e "${GREEN}Certificate extracted successfully ($(stat -c%s "$SSL_CERT_DIR/tls.crt") bytes)${NC}"
            echo "Certificate info:"
            openssl x509 -in "$SSL_CERT_DIR/tls.crt" -text -noout | head -10
        else
            echo -e "${RED}Certificate extraction failed${NC}"
            exit 1
        fi

        if [ -s "$SSL_CERT_DIR/tls.key" ]; then
            echo -e "${GREEN}Private key extracted successfully ($(stat -c%s "$SSL_CERT_DIR/tls.key") bytes)${NC}"
            echo "Private key info:"
            openssl rsa -in "$SSL_CERT_DIR/tls.key" -text -noout | head -5
        else
            echo -e "${RED}Private key extraction failed${NC}"
            exit 1
        fi

        # Test if certificate and key match
        echo -e "${YELLOW}Testing certificate and key compatibility...${NC}"
        cert_md5=$(openssl x509 -noout -modulus -in "$SSL_CERT_DIR/tls.crt" | openssl md5)
        key_md5=$(openssl rsa -noout -modulus -in "$SSL_CERT_DIR/tls.key" | openssl md5)

        if [ "$cert_md5" = "$key_md5" ]; then
            echo -e "${GREEN}Certificate and private key match!${NC}"
        else
            echo -e "${RED}Certificate and private key do not match${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Combined certificate file not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}cPanel SSL directory not found: $CPANEL_SSL_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}SSL extraction complete. Files saved in $SSL_CERT_DIR${NC}"