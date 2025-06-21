# Image Pull Secrets Configuration Guide

This guide explains how to configure image pull secrets for accessing private container registries with your JupyterHub deployment.

## Overview

JupyterHub deployments often need to pull container images from private registries for:
- **Hub images**: Custom JupyterHub images with organizational authentication
- **Proxy images**: Custom configurable-http-proxy builds
- **Singleuser images**: Custom notebook images with proprietary packages
- **Init containers**: Custom setup or data loading containers

## Configuration Methods

### Method 1: Automatic Secret Creation (Recommended)

Configure credentials in `values.yaml` and let Helm create the secrets:

```yaml
global:
  imagePullSecrets:
    # Docker Hub private repositories
    - name: docker-hub-secret
      registry: https://index.docker.io/v1/
      username: mycompany
      password: dckr_pat_1234567890abcdef  # Docker personal access token
      email: admin@company.com

    # Private Harbor registry
    - name: harbor-secret
      registry: https://harbor.company.com
      username: robot$jupyterhub
      password: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
      email: noreply@company.com

    # AWS ECR (Elastic Container Registry)
    - name: ecr-secret
      registry: 123456789012.dkr.ecr.us-west-2.amazonaws.com
      username: AWS
      password: eyJwYXlsb2FkIjoiN3BRaEh...  # ECR token (expires in 12 hours)
      email: aws@company.com

    # Google Container Registry (GCR)
    - name: gcr-secret
      registry: https://gcr.io
      username: _json_key
      password: |
        {
          "type": "service_account",
          "project_id": "my-project",
          "private_key_id": "1234567890abcdef",
          "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
          "client_email": "jupyterhub@my-project.iam.gserviceaccount.com",
          "client_id": "123456789012345678901",
          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
          "token_uri": "https://oauth2.googleapis.com/token"
        }
      email: jupyterhub@my-project.iam.gserviceaccount.com

    # Azure Container Registry (ACR)
    - name: acr-secret
      registry: myregistry.azurecr.io
      username: myregistry
      password: abcdef1234567890+ABCDEF/1234567890  # ACR admin password
      email: admin@company.com

    # Quay.io private repositories
    - name: quay-secret
      registry: https://quay.io
      username: myorg+robot
      password: ABCD1234EFGH5678IJKL9012MNOP3456  # Robot account token
      email: admin@company.com
```

### Method 2: Reference Existing Secrets

If you prefer to create secrets manually or via external tools (CI/CD, secret management systems):

```yaml
global:
  existingImagePullSecrets:
    - name: manually-created-secret
    - name: external-secret-operator-managed
    - name: sealed-secret-registry-creds
```

Create the secrets manually:

```bash
# Docker Hub
kubectl create secret docker-registry docker-hub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=mycompany \
  --docker-password=dckr_pat_1234567890abcdef \
  --docker-email=admin@company.com \
  --namespace=jupyterhub

# Private registry with self-signed certificate
kubectl create secret docker-registry private-registry-secret \
  --docker-server=https://registry.internal.company.com \
  --docker-username=serviceaccount \
  --docker-password=secrettoken \
  --docker-email=noreply@company.com \
  --namespace=jupyterhub
```

## Registry-Specific Configuration

### AWS ECR Integration

For AWS ECR, tokens expire every 12 hours. Consider using IRSA (IAM Roles for Service Accounts):

```yaml
# Use ECR credential helper instead of static tokens
hub:
  extraEnv:
    - name: AWS_REGION
      value: us-west-2
    - name: AWS_ROLE_ARN
      value: arn:aws:iam::123456789012:role/JupyterHubECRRole
  
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/JupyterHubECRRole
```

### Google GCR with Workload Identity

```yaml
hub:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: jupyterhub@my-project.iam.gserviceaccount.com

global:
  # No imagePullSecrets needed with Workload Identity
  imagePullSecrets: []
```

### Harbor with Robot Accounts

1. Create a robot account in Harbor with pull permissions
2. Generate a token for the robot account
3. Configure the secret:

```yaml
global:
  imagePullSecrets:
    - name: harbor-robot-secret
      registry: https://harbor.company.com
      username: robot$jupyterhub-puller
      password: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
      email: noreply@company.com
```

## Image Configuration Examples

### Using Private Hub Image

```yaml
hub:
  image:
    repository: harbor.company.com/jupyterhub/k8s-hub
    tag: "4.2.0-custom"
    pullPolicy: IfNotPresent
```

### Using Private Singleuser Images

```yaml
singleuser:
  image:
    repository: gcr.io/my-project/custom-notebook
    tag: "python-3.11-gpu"
    pullPolicy: IfNotPresent

  # Multiple profiles with different private images
  profileList:
    - display_name: "Data Science Environment"
      description: "Custom data science stack with proprietary libraries"
      kubespawner_override:
        image: "harbor.company.com/datascience/notebook:latest"
        cpu_limit: 2
        mem_limit: "4G"
    
    - display_name: "ML Training Environment"
      description: "GPU-enabled environment for machine learning"
      kubespawner_override:
        image: "registry.company.com/ml/training:cuda-11.8"
        cpu_limit: 4
        mem_limit: "16G"
        extra_resource_limits:
          nvidia.com/gpu: 1
```

## Security Best Practices

### 1. Use Robot/Service Accounts
- Create dedicated service accounts for JupyterHub
- Grant minimum required permissions (pull only)
- Rotate credentials regularly

### 2. Token Management
- Use short-lived tokens where possible
- Store sensitive credentials in external secret management systems
- Consider using External Secrets Operator or Sealed Secrets

### 3. Registry Security
- Use HTTPS for all registry communications
- Validate registry certificates
- Consider using private registries within your network

### 4. Image Scanning
- Scan images for vulnerabilities before deployment
- Use admission controllers to enforce image policies
- Implement image signing and verification

## Troubleshooting

### Common Issues

1. **ImagePullBackOff Error**
   ```bash
   # Check secret exists
   kubectl get secrets -n jupyterhub | grep registry
   
   # Verify secret content
   kubectl get secret docker-hub-secret -n jupyterhub -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
   
   # Check pod events
   kubectl describe pod hub-xxx -n jupyterhub
   ```

2. **Invalid Registry URL**
   - Ensure registry URL matches exactly (including https://)
   - For Docker Hub, use `https://index.docker.io/v1/`
   - For other registries, include the full path

3. **Expired Tokens**
   - ECR tokens expire every 12 hours
   - Service account tokens may have expiration
   - Consider using IAM roles instead of static credentials

4. **Permission Denied**
   - Verify the service account has pull permissions
   - Check if the repository exists and is accessible
   - Ensure the registry supports the image manifest format

### Debugging Commands

```bash
# Test registry login manually
docker login https://registry.company.com
docker pull harbor.company.com/jupyterhub/k8s-hub:4.2.0

# Check Kubernetes secret
kubectl get secret harbor-secret -o yaml

# Verify imagePullSecrets are attached to ServiceAccount
kubectl get serviceaccount hub -o yaml

# Check pod image pull status
kubectl get events --field-selector involvedObject.kind=Pod
```

## Migration Guide

### From Docker Compose to Kubernetes

If migrating from Docker Compose with private images:

1. **Export existing credentials**:
   ```bash
   cat ~/.docker/config.json
   ```

2. **Convert to Kubernetes secrets**:
   ```bash
   kubectl create secret generic regcred \
     --from-file=.dockerconfigjson=~/.docker/config.json \
     --type=kubernetes.io/dockerconfigjson
   ```

3. **Update values.yaml**:
   ```yaml
   global:
     existingImagePullSecrets:
       - name: regcred
   ```

### From Legacy Helm Charts

Update your existing values.yaml:

```yaml
# Old format
imagePullSecrets:
  - regcred

# New format
global:
  existingImagePullSecrets:
    - name: regcred
```

This guide ensures your JupyterHub deployment can securely access private container registries while following security best practices.