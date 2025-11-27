#!/bin/bash

# Script to create a new SSL Certificate Authority and issue a certificate
# Usage: ./create_ssl_cert.sh [domain]

set -e

# Configuration
DOMAIN="${1:-localhost}"
CA_DIR="./ssl_ca"
CERT_DIR="./ssl_certs"
CA_KEY="${CA_DIR}/ca-key.pem"
CA_CERT="${CA_DIR}/ca-cert.pem"
SERVER_KEY="${CERT_DIR}/${DOMAIN}-key.pem"
SERVER_CSR="${CERT_DIR}/${DOMAIN}-csr.pem"
SERVER_CERT="${CERT_DIR}/${DOMAIN}-cert.pem"
DAYS_VALID_CA=3650
DAYS_VALID_CERT=825

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SSL Certificate Authority and Certificate Generator ===${NC}"
echo -e "Domain: ${GREEN}${DOMAIN}${NC}"
echo ""

# Create directories
mkdir -p "${CA_DIR}" "${CERT_DIR}"

# Step 1: Create CA private key
if [ ! -f "${CA_KEY}" ]; then
    echo -e "${BLUE}[1/6] Generating CA private key...${NC}"
    openssl genrsa -out "${CA_KEY}" 4096
    chmod 400 "${CA_KEY}"
    echo -e "${GREEN}✓ CA private key created${NC}"
else
    echo -e "${GREEN}✓ CA private key already exists${NC}"
fi

# Step 2: Create CA certificate
if [ ! -f "${CA_CERT}" ]; then
    echo -e "${BLUE}[2/6] Creating CA certificate...${NC}"
    openssl req -new -x509 -days ${DAYS_VALID_CA} -key "${CA_KEY}" -out "${CA_CERT}" \
        -subj "/C=US/ST=State/L=City/O=Local CA/OU=IT/CN=Local Certificate Authority"
    echo -e "${GREEN}✓ CA certificate created (valid for ${DAYS_VALID_CA} days)${NC}"
else
    echo -e "${GREEN}✓ CA certificate already exists${NC}"
fi

# Step 3: Generate server private key
echo -e "${BLUE}[3/6] Generating server private key...${NC}"
openssl genrsa -out "${SERVER_KEY}" 2048
chmod 400 "${SERVER_KEY}"
echo -e "${GREEN}✓ Server private key created${NC}"

# Step 4: Create server certificate signing request (CSR)
echo -e "${BLUE}[4/6] Creating certificate signing request...${NC}"
openssl req -new -key "${SERVER_KEY}" -out "${SERVER_CSR}" \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=${DOMAIN}"
echo -e "${GREEN}✓ CSR created${NC}"

# Step 5: Create SAN configuration file
SAN_CONFIG="${CERT_DIR}/${DOMAIN}-san.cnf"
cat > "${SAN_CONFIG}" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = IT
CN = ${DOMAIN}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

# Step 6: Sign the certificate with the CA
echo -e "${BLUE}[5/6] Signing certificate with CA...${NC}"
openssl x509 -req -in "${SERVER_CSR}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -CAcreateserial -out "${SERVER_CERT}" -days ${DAYS_VALID_CERT} \
    -extensions v3_req -extfile "${SAN_CONFIG}"
echo -e "${GREEN}✓ Certificate signed (valid for ${DAYS_VALID_CERT} days)${NC}"

# Step 7: Verify the certificate
echo -e "${BLUE}[6/6] Verifying certificate...${NC}"
openssl verify -CAfile "${CA_CERT}" "${SERVER_CERT}"

# Display summary
echo ""
echo -e "${BLUE}=== Certificate Generation Complete ===${NC}"
echo ""
echo "CA Certificate:      ${CA_CERT}"
echo "Server Certificate:  ${SERVER_CERT}"
echo "Server Private Key:  ${SERVER_KEY}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Import CA certificate (${CA_CERT}) into your browser/system trust store"
echo "2. Use server certificate (${SERVER_CERT}) and key (${SERVER_KEY}) in your application"
echo ""
echo -e "${BLUE}Example nginx configuration:${NC}"
echo "  ssl_certificate     ${PWD}/${SERVER_CERT};"
echo "  ssl_certificate_key ${PWD}/${SERVER_KEY};"
echo ""
echo -e "${BLUE}To trust the CA on Linux:${NC}"
echo "  sudo cp ${CA_CERT} /usr/local/share/ca-certificates/local-ca.crt"
echo "  sudo update-ca-certificates"
echo ""
echo -e "${GREEN}Done!${NC}"
