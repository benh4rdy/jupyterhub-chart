# JupyterHub Service Configuration Guide

This guide explains the comprehensive service definitions created for the JupyterHub Helm chart, covering all networking aspects from internal communication to external access and monitoring.

## Overview of Services

### 1. Hub Service (Internal)
**Purpose**: Provides internal access to the JupyterHub application for proxy and singleuser communication

```yaml
hub:
  service:
    type: ClusterIP
    clusterIP: ""
    annotations: {}
    sessionAffinity: None
    extraPorts: []
    headless:
      enabled: false  # For StatefulSet scenarios
```

**Key Features**:
- ClusterIP service for internal cluster communication
- Health check endpoint on port 8081
- Optional metrics endpoint on port 8080
- Session affinity support for sticky sessions

### 2. Proxy API Service (Internal)
**Purpose**: Internal proxy management and configuration API

```yaml
proxy:
  api:
    service:
      type: ClusterIP
      clusterIP: ""
      annotations: {}
      extraPorts: []
```

**Key Features**:
- Internal-only access on port 8001
- Used by hub to manage proxy routes
- No external exposure

### 3. Proxy Public Service (External)
**Purpose**: Main entry point for user access to JupyterHub

```yaml
proxy:
  service:
    type: ClusterIP  # LoadBalancer, NodePort, ExternalName
    port: 80
    targetPort: http
    
    # LoadBalancer configuration
    loadBalancerIP: ""
    loadBalancerSourceRanges: []
    
    # NodePort configuration  
    nodePort: ""
    httpsPort: 443
    httpsNodePort: ""
    
    # Advanced configuration
    clusterIP: ""
    externalIPs: []
    sessionAffinity: None
    annotations: {}
    extraPorts: []
```

## Service Types and Use Cases

### ClusterIP (Default)
**Use Case**: Internal access only, used with Ingress controllers

```yaml
proxy:
  service:
    type: ClusterIP
    port: 80
    targetPort: http
```

**Benefits**:
- Most secure (no external exposure)
- Works with any Ingress controller
- Supports advanced networking features
- Lowest resource overhead

**Example with Ingress**:
```yaml
proxy:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: jupyter.company.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: jupyter-tls
        hosts:
          - jupyter.company.com
```

### LoadBalancer
**Use Case**: Direct external access via cloud load balancer

```yaml
proxy:
  service:
    type: LoadBalancer
    port: 80
    targetPort: http
    loadBalancerIP: "203.0.113.10"  # Static IP
    loadBalancerSourceRanges:
      - "10.0.0.0/8"      # Corporate network
      - "192.168.0.0/16"  # VPN users
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-internal: "false"
```

**Cloud Provider Examples**:

**AWS ELB/ALB**:
```yaml
proxy:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:region:account:certificate/cert-id
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

**Google Cloud Load Balancer**:
```yaml
proxy:
  service:
    type: LoadBalancer
    annotations:
      cloud.google.com/load-balancer-type: External
      networking.gke.io/load-balancer-type: External
```

**Azure Load Balancer**:
```yaml
proxy:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "false"
      service.beta.kubernetes.io/azure-load-balancer-resource-group: my-rg
```

### NodePort
**Use Case**: Direct node access, on-premise deployments

```yaml
proxy:
  service:
    type: NodePort
    port: 80
    nodePort: 30080
    httpsPort: 443
    httpsNodePort: 30443
```

**Benefits**:
- Works without cloud load balancer
- Predictable port assignments
- Good for on-premise deployments

### ExternalName
**Use Case**: Redirect to external service

```yaml
proxy:
  service:
    type: ExternalName
    externalName: external-jupyter.company.com
```

## Advanced Service Features

### Session Affinity
**Purpose**: Ensure users stick to the same backend pod

```yaml
proxy:
  service:
    sessionAffinity: ClientIP
    sessionAffinityConfig:
      clientIP:
        timeoutSeconds: 10800  # 3 hours
```

### External IPs
**Purpose**: Assign specific external IPs

```yaml
proxy:
  service:
    externalIPs:
      - 203.0.113.10
      - 203.0.113.11
```

### Extra Ports
**Purpose**: Expose additional services

```yaml
hub:
  service:
    extraPorts:
      - name: grpc
        port: 9000
        targetPort: 9000
        protocol: TCP
      - name: debug
        port: 5678
        targetPort: 5678
        protocol: TCP

proxy:
  service:
    extraPorts:
      - name: websocket
        port: 8080
        targetPort: 8080
        protocol: TCP
```

## Monitoring Services

### Hub Metrics Service
**Purpose**: Prometheus metrics collection from JupyterHub

```yaml
monitoring:
  prometheus:
    enabled: true
```

**Automatically creates**:
- Hub metrics service on port 8080
- Proxy metrics service on port 8002
- ServiceMonitor resources for Prometheus Operator

### Service Monitoring Configuration

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jupyterhub-hub
spec:
  selector:
    matchLabels:
      prometheus.io/service-monitor: "true"
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

## SSL/TLS Configuration

### HTTPS Termination at Service Level

```yaml
proxy:
  https:
    enabled: true
    type: secret
    secret:
      name: jupyterhub-tls
      crt: tls.crt
      key: tls.key
  
  service:
    port: 443
    targetPort: https
    annotations:
      service.beta.kubernetes.io/backend-protocol: "HTTPS"
```

### SSL Passthrough

```yaml
proxy:
  service:
    annotations:
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

## Service Mesh Integration

### Istio Service Mesh

```yaml
proxy:
  service:
    annotations:
      sidecar.istio.io/inject: "true"
      traffic.sidecar.istio.io/includeInboundPorts: "8000"
      traffic.sidecar.istio.io/excludeOutboundPorts: "8001"
```

### Linkerd Service Mesh

```yaml
proxy:
  service:
    annotations:
      linkerd.io/inject: enabled
      config.linkerd.io/proxy-cpu-request: "100m"
      config.linkerd.io/proxy-memory-request: "20Mi"
```

## Development and Debugging

### Debug Service (Development Only)

```yaml
development:
  debug: true
  debugNodePort: 30678
```

**Creates**:
- NodePort service for remote debugging
- Debug endpoint on port 5678
- Development-only annotations

### Health Check Services

```yaml
# Readiness probe endpoint
hub:
  service:
    extraPorts:
      - name: health
        port: 8082
        targetPort: 8082
        protocol: TCP
```

## Production Deployment Examples

### Small Organization (Internal Access)

```yaml
proxy:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: jupyter.internal.company.com
    tls:
      - secretName: internal-tls
```

### Medium Organization (External Access)

```yaml
proxy:
  service:
    type: LoadBalancer
    loadBalancerSourceRanges:
      - "10.0.0.0/8"
      - "203.0.113.0/24"
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      external-dns.alpha.kubernetes.io/hostname: jupyter.company.com
```

### Large Enterprise (Multi-Region)

```yaml
proxy:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      external-dns.alpha.kubernetes.io/hostname: jupyter.company.com
      external-dns.alpha.kubernetes.io/ttl: "60"
    
    # Geographic load balancing
    loadBalancerSourceRanges:
      - "10.0.0.0/8"     # Corporate networks
      - "172.16.0.0/12"  # Partner networks
```

## Troubleshooting Services

### Common Service Issues

1. **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n jupyterhub

# Verify service selector matches pod labels
kubectl get pods -n jupyterhub --show-labels
kubectl describe service proxy-public -n jupyterhub

# Test internal connectivity
kubectl run debug --image=busybox --rm -it -- nslookup proxy-public.jupyterhub.svc.cluster.local
```

2. **LoadBalancer Pending**
```bash
# Check cloud provider integration
kubectl describe service proxy-public -n jupyterhub

# Verify cloud controller manager
kubectl get pods -n kube-system | grep cloud-controller

# Check service annotations
kubectl get service proxy-public -o yaml
```

3. **SSL/TLS Issues**
```bash
# Check certificate secrets
kubectl get secrets -n jupyterhub | grep tls

# Verify certificate validity
kubectl get secret jupyterhub-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Test HTTPS connectivity
curl -k -v https://jupyter.company.com
```

### Service Performance Monitoring

```yaml
# Add performance monitoring annotations
proxy:
  service:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8000"
      prometheus.io/path: "/metrics"
      
      # Service latency tracking
      monitor.company.com/latency-threshold: "500ms"
      monitor.company.com/error-rate-threshold: "1%"
```

This comprehensive service configuration ensures that your JupyterHub deployment supports all networking requirements from development to enterprise production environments with proper monitoring, security, and performance characteristics.