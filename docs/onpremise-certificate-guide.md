# On-Premise Certificate Management Guide for JupyterHub

This guide is specifically designed for closed corporate environments where JupyterHub serves a group of data scientists with internal PKI and corporate security requirements.

## Overview for Corporate Environments

In a closed corporate environment, certificate management typically involves:
- **Corporate PKI**: Internal Certificate Authority managed by IT Security
- **Internal Domains**: `.company.com`, `.company.local`, `.internal` domains
- **Manual Processes**: IT-controlled certificate issuance and renewal
- **Security Compliance**: Corporate security policies and audit requirements
- **Network Isolation**: No external internet access for automatic certificate provisioning

## Corporate PKI Integration

### 1. Obtaining Certificates from Corporate CA

#### Certificate Request Process
```bash
#!/bin/bash
# request-corporate-cert.sh
# Script to generate CSR for corporate CA

COMMON_NAME="jupyter.company.com"
ORG="Data Science Team"
ORG_UNIT="IT Department"
COUNTRY="US"
STATE="CA"
CITY="Corporate HQ"

# Generate private key
openssl genrsa -out server.key 2048

# Generate Certificate Signing Request
openssl req -new -key server.key -out server.csr -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${ORG_UNIT}/CN=${COMMON_NAME}"

# Add Subject Alternative Names
cat > san.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = jupyter.company.com
DNS.2 = notebooks.company.com
DNS.3 = jupyter.internal
DNS.4 = localhost
IP.1 = 10.0.0.100
EOF

# Generate CSR with SAN
openssl req -new -key server.key -out server.csr -config san.conf

echo "Certificate Signing Request generated:"
echo "- Private Key: server.key"
echo "- CSR: server.csr"
echo ""
echo "Next steps:"
echo "1. Submit server.csr to your Corporate CA"
echo "2. Wait for certificate approval and issuance"
echo "3. Download the signed certificate"
echo "4. Use deploy-certificate.sh to install"
```

#### Certificate Deployment
```bash
#!/bin/bash
# deploy-certificate.sh
# Deploy corporate certificate to Kubernetes

NAMESPACE="jupyterhub"
SECRET_NAME="jupyter-corporate-tls"
CERT_FILE="server.crt"
KEY_FILE="server.key"
CA_FILE="corporate-ca.crt"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Error: Certificate files not found"
    echo "Required files: $CERT_FILE, $KEY_FILE"
    exit 1
fi

echo "Deploying corporate certificate to Kubernetes..."

# Create TLS secret
kubectl create secret tls $SECRET_NAME \
    --cert=$CERT_FILE \
    --key=$KEY_FILE \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

# Create CA certificate configmap if provided
if [ -f "$CA_FILE" ]; then
    kubectl create configmap corporate-ca-certs \
        --from-file=ca.crt=$CA_FILE \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Verify certificate
echo "Verifying certificate..."
kubectl get secret $SECRET_NAME -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Restart proxy to use new certificate
kubectl rollout restart deployment/my-release-my-jupyterhub-proxy -n $NAMESPACE

echo "Certificate deployment completed successfully"
```

### 2. Configuration for Corporate Environment

#### values-corporate.yaml
```yaml
global:
  environment: production
  team: data-science
  commonLabels:
    environment: production
    team: data-science
    security-classification: internal
  commonAnnotations:
    contact: data-team@company.com
    security-contact: security@company.com
    compliance: "corporate-standard"

proxy:
  https:
    enabled: true
    type: secret
    hosts:
      - jupyter.company.com
      - notebooks.company.com
      - jupyter.internal
    
    redirect: true
    
    secret:
      name: jupyter-corporate-tls
    
    corporateCA:
      enabled: true
      certificates:
        root-ca: |
          -----BEGIN CERTIFICATE-----
          MIIDXTCCAkWgAwIBAgIJAKL0UG+0nZKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
          BAYTAkNPMRMwEQYDVQQIDApDb3Jwb3JhdGUxITAfBgNVBAoMGENvcnBvcmF0ZSBJ
          VCBEZXBhcnRtZW50MQswCQYDVQQGEwJVUzAeFw0yMDAxMDEwMDAwMDBaFw0zMDEy
          MzEyMzU5NTlaMEUxCzAJBgNVBAYTAkNPMRMwEQYDVQQIDApDb3Jwb3JhdGUxITAf
          BgNVBAoMGENvcnBvcmF0ZSBJVCBEZXBhcnRtZW50MQswCQYDVQQGEwJVUzCCASIw
          DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMExample...
          -----END CERTIFICATE-----
        
        intermediate-ca: |
          -----BEGIN CERTIFICATE-----
          MIIDXTCCAkWgAwIBAgIJAKL0UG+0nZKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
          BAYTAkNPMRMwEQYDVQQIDApDb3Jwb3JhdGUxITAfBgNVBAoMGENvcnBvcmF0ZSBJ
          VCBEZXBhcnRtZW50MQswCQYDVQQGEwJVUzAeFw0yMDAxMDEwMDAwMDBaFw0zMDEy
          MzEyMzU5NTlaMEUxCzAJBgNVBAYTAkNPMRMwEQYDVQQIDApDb3Jwb3JhdGUxITAf
          BgNVBAoMGENvcnBvcmF0ZSBJVCBEZXBhcnRtZW50MQswCQYDVQQGEwJVUzCCASIw
          DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMExample...
          -----END CERTIFICATE-----
    
    corporate:
      ca: "Corporate IT Security CA"
      contact: "security@company.com"
      renewalProcess: "Submit ticket to IT Security (SNOW-12345)"
    
    management:
      autoUpdate:
        enabled: true
        schedule: "0 2 * * 0"  # Weekly check
        warningDays: 30
        email: "data-team@company.com"

  service:
    type: ClusterIP  # Use with internal load balancer
    annotations:
      metallb.universe.tf/address-pool: internal-pool
      metallb.universe.tf/allow-shared-ip: jupyter-shared

# Internal network configuration
hub:
  extraAnnotations:
    network.company.com/zone: internal
    backup.company.com/schedule: "0 3 * * *"

singleuser:
  extraAnnotations:
    network.company.com/isolation: standard
    monitoring.company.com/collect-metrics: "true"
```

## Certificate Management Workflows

### 1. Initial Certificate Setup

```bash
#!/bin/bash
# initial-setup.sh
# Complete initial certificate setup

echo "=== JupyterHub Certificate Setup ==="
echo "This script will set up SSL certificates for your JupyterHub deployment"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "Error: openssl not found. Please install openssl first."
    exit 1
fi

# Configuration
read -p "Enter JupyterHub hostname (e.g., jupyter.company.com): " HOSTNAME
read -p "Enter organization name: " ORG
read -p "Enter Kubernetes namespace [jupyterhub]: " NAMESPACE
NAMESPACE=${NAMESPACE:-jupyterhub}

echo ""
echo "Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Organization: $ORG"
echo "  Namespace: $NAMESPACE"
echo ""

read -p "Proceed with setup? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Generate certificate request
echo "Generating certificate signing request..."
./request-corporate-cert.sh

echo ""
echo "=== Next Steps ==="
echo "1. Submit the generated CSR (server.csr) to your Corporate CA"
echo "2. Once you receive the signed certificate, save it as 'server.crt'"
echo "3. Save the CA certificate as 'corporate-ca.crt'"
echo "4. Run: ./deploy-certificate.sh"
echo ""
echo "Files generated:"
echo "  - server.key (private key - keep secure!)"
echo "  - server.csr (certificate signing request)"
```

### 2. Certificate Renewal Process

```bash
#!/bin/bash
# renew-certificate.sh
# Automated certificate renewal workflow

NAMESPACE="jupyterhub"
SECRET_NAME="jupyter-corporate-tls"
BACKUP_DIR="./cert-backups/$(date +%Y%m%d-%H%M%S)"

echo "=== Certificate Renewal Process ==="

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup current certificate
echo "Backing up current certificate..."
kubectl get secret $SECRET_NAME -n $NAMESPACE -o yaml > $BACKUP_DIR/current-cert.yaml

# Extract current certificate for analysis
kubectl get secret $SECRET_NAME -o jsonpath='{.data.tls\.crt}' | base64 -d > $BACKUP_DIR/current-cert.crt

# Check expiry
EXPIRY_DATE=$(openssl x509 -in $BACKUP_DIR/current-cert.crt -noout -enddate | cut -d= -f2)
EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

echo "Current certificate expires in $DAYS_UNTIL_EXPIRY days ($EXPIRY_DATE)"

if [ $DAYS_UNTIL_EXPIRY -gt 30 ]; then
    echo "Certificate is not due for renewal yet (expires in >30 days)"
    read -p "Continue with renewal anyway? (y/N): " FORCE_RENEWAL
    if [[ ! $FORCE_RENEWAL =~ ^[Yy]$ ]]; then
        echo "Renewal cancelled."
        exit 0
    fi
fi

# Check if new certificate files exist
if [ ! -f "server.crt" ] || [ ! -f "server.key" ]; then
    echo "Error: New certificate files not found"
    echo "Please ensure you have:"
    echo "  - server.crt (new signed certificate)"
    echo "  - server.key (private key)"
    exit 1
fi

# Validate new certificate
echo "Validating new certificate..."
openssl x509 -in server.crt -text -noout | grep -E "(Subject|Issuer|Not After)"

if ! openssl x509 -in server.crt -checkend 86400 -noout; then
    echo "Warning: New certificate expires within 24 hours!"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Renewal cancelled."
        exit 0
    fi
fi

# Deploy new certificate
echo "Deploying new certificate..."
./deploy-certificate.sh

# Verify deployment
echo "Verifying deployment..."
sleep 10
kubectl get pods -n $NAMESPACE | grep proxy

echo ""
echo "Certificate renewal completed successfully!"
echo "Backup saved to: $BACKUP_DIR"
```

### 3. Certificate Monitoring

```bash
#!/bin/bash
# monitor-certificates.sh
# Monitor certificate expiry and health

NAMESPACE="jupyterhub"
SECRET_NAME="jupyter-corporate-tls"
WARNING_DAYS=30
CRITICAL_DAYS=7

echo "=== Certificate Health Check ==="
echo "Namespace: $NAMESPACE"
echo "Secret: $SECRET_NAME"
echo ""

# Check if secret exists
if ! kubectl get secret $SECRET_NAME -n $NAMESPACE &>/dev/null; then
    echo "ERROR: Certificate secret not found!"
    exit 1
fi

# Extract and analyze certificate
kubectl get secret $SECRET_NAME -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/cert.crt

# Basic certificate info
echo "Certificate Information:"
openssl x509 -in /tmp/cert.crt -noout -subject -issuer -dates

# Calculate days until expiry
EXPIRY_DATE=$(openssl x509 -in /tmp/cert.crt -noout -enddate | cut -d= -f2)
EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

echo ""
echo "Expiry Status:"
echo "  Days until expiry: $DAYS_UNTIL_EXPIRY"

if [ $DAYS_UNTIL_EXPIRY -lt $CRITICAL_DAYS ]; then
    echo "  Status: CRITICAL - Certificate expires very soon!"
    EXIT_CODE=2
elif [ $DAYS_UNTIL_EXPIRY -lt $WARNING_DAYS ]; then
    echo "  Status: WARNING - Certificate expires soon"
    EXIT_CODE=1
else
    echo "  Status: OK"
    EXIT_CODE=0
fi

# Check certificate chain
echo ""
echo "Certificate Chain Validation:"
if openssl verify -CAfile /tmp/cert.crt /tmp/cert.crt &>/dev/null; then
    echo "  Chain validation: OK"
else
    echo "  Chain validation: WARNING - Could not verify full chain"
fi

# Check SAN entries
echo ""
echo "Subject Alternative Names:"
openssl x509 -in /tmp/cert.crt -noout -ext subjectAltName

# Test actual connectivity
echo ""
echo "Connectivity Test:"
HOSTNAME=$(kubectl get secret $SECRET_NAME -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject | grep -o 'CN=[^,]*' | cut -d= -f2)

if [ -n "$HOSTNAME" ]; then
    if openssl s_client -connect $HOSTNAME:443 -servername $HOSTNAME </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        echo "  SSL connectivity: OK"
    else
        echo "  SSL connectivity: WARNING - Connection issues detected"
    fi
fi

# Cleanup
rm -f /tmp/cert.crt

echo ""
echo "Health check completed."
exit $EXIT_CODE
```

## Security Best Practices for Corporate Environments

### 1. Certificate Storage Security

```yaml
# RBAC for certificate management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: jupyterhub
  name: certificate-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["jupyter-corporate-tls", "corporate-ca-certs"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  resourceNames: ["my-release-my-jupyterhub-proxy"]
  verbs: ["get", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: certificate-managers
  namespace: jupyterhub
subjects:
- kind: User
  name: security-admin@company.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: it-security
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: certificate-manager
  apiGroup: rbac.authorization.k8s.io
```

### 2. Audit and Compliance

```bash
#!/bin/bash
# audit-certificates.sh
# Generate compliance report for certificate usage

echo "=== Certificate Compliance Audit ===" > cert-audit-$(date +%Y%m%d).txt
echo "Generated: $(date)" >> cert-audit-$(date +%Y%m%d).txt
echo "" >> cert-audit-$(date +%Y%m%d).txt

# List all TLS secrets
echo "TLS Secrets Inventory:" >> cert-audit-$(date +%Y%m%d).txt
kubectl get secrets --all-namespaces -o json | \
  jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace)/\(.metadata.name)"' >> cert-audit-$(date +%Y%m%d).txt

echo "" >> cert-audit-$(date +%Y%m%d).txt

# Analyze each certificate
for secret in $(kubectl get secrets --all-namespaces -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace)/\(.metadata.name)"'); do
    namespace=$(echo $secret | cut -d/ -f1)
    name=$(echo $secret | cut -d/ -f2)
    
    echo "Certificate: $secret" >> cert-audit-$(date +%Y%m%d).txt
    
    # Extract certificate details
    kubectl get secret $name -n $namespace -o jsonpath='{.data.tls\.crt}' | base64 -d | \
      openssl x509 -noout -subject -issuer -dates >> cert-audit-$(date +%Y%m%d).txt
    
    echo "" >> cert-audit-$(date +%Y%m%d).txt
done

echo "Audit report generated: cert-audit-$(date +%Y%m%d).txt"
```

## Troubleshooting Common Issues

### 1. Certificate Chain Issues

```bash
# Verify certificate chain
openssl verify -CAfile corporate-ca.crt server.crt

# Check for missing intermediate certificates
openssl s_client -connect jupyter.company.com:443 -showcerts

# Test certificate with specific CA bundle
curl --cacert corporate-ca.crt https://jupyter.company.com
```

### 2. DNS and Network Issues

```bash
# Test internal DNS resolution
nslookup jupyter.company.com
dig jupyter.company.com

# Test connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it -- wget -O- https://jupyter.company.com
```

### 3. Permission Issues

```bash
# Check secret permissions
kubectl auth can-i get secrets/jupyter-corporate-tls --namespace=jupyterhub

# Verify service account permissions
kubectl auth can-i --list --as=system:serviceaccount:jupyterhub:default
```

This guide provides comprehensive certificate management for closed corporate  environments with focus on security, compliance, and operational procedures suitable for data science teams.