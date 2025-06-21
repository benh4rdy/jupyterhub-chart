# HTTPS Configuration Guide for JupyterHub

This guide explains how to configure HTTPS/SSL for your JupyterHub deployment, supporting multiple certificate sources and scenarios from development to production.

## Overview

HTTPS is essential for:
- **Data Protection**: Encrypting user credentials and notebook data
- **Authentication Security**: Protecting login sessions and tokens
- **Compliance**: Meeting security standards for enterprise deployments
- **Browser Compatibility**: Modern browsers require HTTPS for many features
- **WebSocket Security**: Secure communication for JupyterLab terminals and kernels

## Certificate Types Supported

### 1. Self-Signed Certificates (Development)
**Use Case**: Development, testing, internal environments

```yaml
proxy:
  https:
    enabled: true
    type: self-signed
    hosts:
      - jupyter.dev.local
      - localhost
    
    selfSigned:
      enabled: true
      commonName: "jupyter.dev.local"
      caCommonName: "JupyterHub Development CA"
      validityDays: 365
      
      altNames:
        - localhost
        - "*.jupyter.dev.local"
        - jupyter.internal
      
      organization: "Development Team"
      organizationalUnit: "Data Science"
      country: "US"
      state: "CA"
      locality: "San Francisco"
```

**Benefits**:
- Automatic certificate generation
- No external dependencies
- Quick setup for development
- Supports Subject Alternative Names (SANs)

**Limitations**:
- Browser warnings (not trusted)
- Not suitable for production
- Manual trust required

### 2. Let's Encrypt Certificates (Production)
**Use Case**: Public production deployments

**Prerequisites**: cert-manager installed in cluster

```yaml
proxy:
  https:
    enabled: true
    type: letsencrypt
    hosts:
      - jupyter.company.com
      - notebooks.company.com
    
    letsencrypt:
      email: admin@company.com
      issuer: letsencrypt-prod
      issuerKind: ClusterIssuer
      
      # Certificate configuration
      duration: "2160h"  # 90 days
      renewBefore: "360h"  # Renew 15 days before expiry
      algorithm: RSA
      keySize: 2048
      
      usages:
        - digital signature
        - key encipherment
        - server auth
```

**Required ClusterIssuer**:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@company.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
    - dns01:
        cloudflare:
          email: admin@company.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

**Benefits**:
- Free, trusted certificates
- Automatic renewal
- Browser trusted
- No certificate warnings

### 3. External Certificates (Enterprise)
**Use Case**: Corporate CA, purchased certificates, existing PKI

```yaml
proxy:
  https:
    enabled: true
    type: secret
    hosts:
      - jupyter.company.com
    
    secret:
      name: jupyter-enterprise-tls
      crt: tls.crt
      key: tls.key
```

**Create the certificate secret**:
```bash
# From certificate files
kubectl create secret tls jupyter-enterprise-tls \
  --cert=path/to/certificate.crt \
  --key=path/to/private.key \
  --namespace=jupyterhub

# From PEM data
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: jupyter-enterprise-tls
  namespace: jupyterhub
type: kubernetes.io/tls
data:
  tls.crt: $(cat certificate.crt | base64 -w 0)
  tls.key: $(cat private.key | base64 -w 0)
EOF
```

## Certificate Trust Bundle

### Corporate CA Integration
**Use Case**: Internal services with corporate certificates

```yaml
proxy:
  https:
    trustBundle:
      enabled: true
      certificates:
        corporate-root-ca: |
          -----BEGIN CERTIFICATE-----
          MIIDXTCCAkWgAwIBAgIJAKL0UG+0nZKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
          BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
          aWRnaXRzIFB0eSBMdGQwHhcNMTkwNjI4MTIwMjA1WhcNMjkwNjI1MTIwMjA1WjBF
          ...
          -----END CERTIFICATE-----
        
        internal-services-ca: |
          -----BEGIN CERTIFICATE-----
          MIIDXTCCAkWgAwIBAgIJAKL0UG+0nZKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
          ...
          -----END CERTIFICATE-----
```

**Benefits**:
- Trust internal services
- Support corporate PKI
- Verify upstream certificates
- Secure external integrations

## Cloud Provider Integration

### AWS Certificate Manager (ACM)
**Use Case**: AWS EKS with ALB Ingress

```yaml
proxy:
  service:
    type: ClusterIP  # Use with ALB
    
  https:
    enabled: false  # Terminate at ALB level

# ALB Ingress configuration
ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012
    alb.ingress.kubernetes.io/ssl-redirect: '443'
  hosts:
    - host: jupyter.company.com
      paths:
        - path: /
          pathType: Prefix
```

### Google Cloud SSL Certificates
**Use Case**: GKE with Google Cloud Load Balancer

```yaml
proxy:
  service:
    type: ClusterIP

# Google Cloud managed certificate
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: jupyter-ssl-cert
spec:
  domains:
    - jupyter.company.com

# Ingress with managed certificate
ingress:
  enabled: true
  className: gce
  annotations:
    networking.gke.io/managed-certificates: jupyter-ssl-cert
    kubernetes.io/ingress.global-static-ip-name: jupyter-ip
```

### Azure Key Vault Integration
**Use Case**: AKS with Azure Key Vault

```yaml
# Azure Key Vault secret provider
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: jupyter-keyvault-ssl
spec:
  provider: azure
  parameters:
    useAzureIdentity: "true"
    objects: |
      array:
        - |
          objectName: jupyter-ssl-cert
          objectType: secret
        - |
          objectName: jupyter-ssl-key
          objectType: secret
  secretObjects:
  - secretName: jupyter-keyvault-tls
    type: kubernetes.io/tls
    data:
    - objectName: jupyter-ssl-cert
      key: tls.crt
    - objectName: jupyter-ssl-key
      key: tls.key

# Use Key Vault certificate
proxy:
  https:
    enabled: true
    type: secret
    secret:
      name: jupyter-keyvault-tls
```

## Advanced HTTPS Configuration

### Mutual TLS (mTLS)
**Use Case**: Client certificate authentication

```yaml
proxy:
  https:
    enabled: true
    type: secret
    
    # Client certificate verification
    clientAuth:
      enabled: true
      mode: require  # require, request, verify_if_given
      caSecret: client-ca-certs
      crlSecret: client-crl  # Certificate Revocation List
```

### HTTPS Redirection
**Use Case**: Force HTTPS for all traffic

```yaml
proxy:
  https:
    enabled: true
    redirect: true  # Redirect HTTP to HTTPS
    
  service:
    ports:
      - name: http
        port: 80
        targetPort: 8000
      - name: https
        port: 443
        targetPort: 8443
```

### Custom SSL/TLS Configuration
**Use Case**: Specific cipher suites, protocols

```yaml
proxy:
  https:
    enabled: true
    
    # Custom TLS configuration
    tls:
      minVersion: "1.2"
      maxVersion: "1.3"
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
      
      # OCSP Stapling
      ocspStapling: true
      
      # HSTS Headers
      hsts:
        enabled: true
        maxAge: 31536000  # 1 year
        includeSubDomains: true
        preload: true
```

## Security Best Practices

### 1. Certificate Validation
```bash
# Check certificate expiration
kubectl get secret jupyter-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates

# Verify certificate chain
kubectl get secret jupyter-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -text

# Check certificate SAN
kubectl get secret jupyter-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -ext subjectAltName
```

### 2. Certificate Rotation
```yaml
# Automatic rotation with cert-manager
proxy:
  https:
    letsencrypt:
      renewBefore: "720h"  # Renew 30 days before expiry
      
# Monitor certificate expiry
monitoring:
  prometheus:
    enabled: true
    rules:
      - alert: CertificateExpirySoon
        expr: (x509_cert_expiry - time()) / 86400 < 30
        labels:
          severity: warning
        annotations:
          summary: "Certificate expires in less than 30 days"
```

### 3. Security Headers
```yaml
proxy:
  https:
    securityHeaders:
      enabled: true
      headers:
        X-Frame-Options: "SAMEORIGIN"
        X-Content-Type-Options: "nosniff"
        X-XSS-Protection: "1; mode=block"
        Strict-Transport-Security: "max-age=31536000; includeSubDomains"
        Content-Security-Policy: "default-src 'self'"
        Referrer-Policy: "strict-origin-when-cross-origin"
```

## Troubleshooting HTTPS Issues

### Common Problems

1. **Certificate Not Found**
```bash
# Check secret exists
kubectl get secrets -n jupyterhub | grep tls

# Verify secret content
kubectl describe secret jupyter-tls -n jupyterhub

# Check certificate validity
kubectl get secret jupyter-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -text -noout
```

2. **Browser Certificate Warnings**
```bash
# Check certificate chain
openssl s_client -connect jupyter.company.com:443 -showcerts

# Verify hostname matches
curl -vI https://jupyter.company.com

# Check for mixed content issues
curl -k https://jupyter.company.com | grep -i "http://"
```

3. **Let's Encrypt Issues**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate jupyter-cert -n jupyterhub

# Check challenge status
kubectl get challenges -n jupyterhub
```

4. **Performance Issues**
```bash
# Test SSL handshake time
curl -w "@curl-format.txt" -o /dev/null -s https://jupyter.company.com

# Monitor SSL metrics
prometheus_query='ssl_handshake_duration_seconds'
```

### SSL Testing Tools

```bash
# SSL Labs test (external)
curl -s "https://api.ssllabs.com/api/v3/analyze?host=jupyter.company.com"

# Local SSL test
testssl.sh jupyter.company.com

# Certificate transparency logs
curl -s "https://crt.sh/?q=jupyter.company.com&output=json"
```

## Production Deployment Examples

### Small Organization (Let's Encrypt)
```yaml
proxy:
  https:
    enabled: true
    type: letsencrypt
    hosts:
      - jupyter.company.com
    letsencrypt:
      email: admin@company.com
      issuer: letsencrypt-prod
  
  service:
    type: ClusterIP
    
  ingress:
    enabled: true
    className: nginx
```

### Enterprise (Corporate CA)
```yaml
proxy:
  https:
    enabled: true
    type: secret
    hosts:
      - jupyter.enterprise.com
    
    secret:
      name: enterprise-tls-cert
    
    trustBundle:
      enabled: true
      certificates:
        corporate-ca: |
          -----BEGIN CERTIFICATE-----
          ...corporate CA certificate...
          -----END CERTIFICATE-----
  
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:...
```

This comprehensive HTTPS configuration ensures secure communication for your JupyterHub deployment across all environments from development to enterprise production.