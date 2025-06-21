# Labels and Annotations Implementation Guide

This guide explains the comprehensive labeling and annotation system implemented for the JupyterHub Helm chart to ensure proper resource organization, monitoring, security, and operational management.

## Overview

Proper labeling and annotations are critical for:
- **Resource Organization**: Grouping and filtering related resources
- **Monitoring and Alerting**: Prometheus metric collection and routing
- **Security Policies**: Network policies and pod security standards
- **Operational Management**: Backup schedules, scaling policies, cost allocation
- **Debugging and Troubleshooting**: Resource relationship tracking
- **Compliance**: Audit trails and change tracking

## Standard Kubernetes Labels

### Required Labels (Applied to All Resources)

```yaml
# Chart identification
helm.sh/chart: my-jupyterhub-0.2.0
app.kubernetes.io/name: my-jupyterhub
app.kubernetes.io/instance: my-release
app.kubernetes.io/version: "4.2.0"
app.kubernetes.io/managed-by: Helm

# Application architecture
app.kubernetes.io/part-of: jupyterhub
app.kubernetes.io/component: hub|proxy|singleuser-server
```

### Component-Specific Labels

#### Hub Component
```yaml
app.kubernetes.io/component: hub
jupyterhub.io/component-type: control-plane
hub.jupyter.org/network-access-proxy-api: "true"
hub.jupyter.org/network-access-proxy-http: "true"
hub.jupyter.org/network-access-singleuser: "true"
```

#### Proxy Component
```yaml
app.kubernetes.io/component: proxy
jupyterhub.io/component-type: gateway
hub.jupyter.org/network-access-hub: "true"
```

#### Singleuser Component
```yaml
app.kubernetes.io/component: singleuser-server
jupyterhub.io/component-type: user-workload
hub.jupyter.org/network-access-hub: "true"
hub.jupyter.org/network-access-proxy: "true"
hub.jupyter.org/username: "{username}"
```

## Custom JupyterHub Labels

### Resource Type Classification
```yaml
jupyterhub.io/component-type: control-plane|gateway|user-workload|security|persistence|observability|config
jupyterhub.io/resource-type: hub|proxy|singleuser|deployment|service|configmap|secret|pvc
```

### Network Access Control
```yaml
hub.jupyter.org/network-access-hub: "true"
hub.jupyter.org/network-access-proxy-api: "true"
hub.jupyter.org/network-access-proxy-http: "true"
hub.jupyter.org/network-access-singleuser: "true"
```

### Resource Ownership and Management
```yaml
jupyterhub.io/owned-by: my-release
jupyterhub.io/managed-by: helm
jupyterhub.io/created-by: my-jupyterhub
```

## Standard Annotations

### Helm Management
```yaml
meta.helm.sh/release-name: my-release
meta.helm.sh/release-namespace: jupyterhub
```

### JupyterHub Metadata
```yaml
jupyterhub.io/chart-version: "0.2.0"
jupyterhub.io/app-version: "4.2.0"
jupyterhub.io/resource-type: hub|proxy|singleuser|deployment|service
```

### Lifecycle Tracking
```yaml
jupyterhub.io/created-at: "2024-01-15T10:30:00Z"
jupyterhub.io/helm-revision: "1"
jupyterhub.io/upgraded-at: "2024-01-20T14:45:00Z"
```

### Network and Security
```yaml
jupyterhub.io/network-access-required: "proxy-api,proxy-http,singleuser"
cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
network-policy.kubernetes.io/ingress: "restricted"
network-policy.kubernetes.io/egress: "restricted"
```

## Component-Specific Annotations

### Deployment Annotations
```yaml
deployment.kubernetes.io/revision: "1"
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/metrics"
```

### Service Annotations
```yaml
service.beta.kubernetes.io/external-traffic: "OnlyLocal"  # For LoadBalancer
service.beta.kubernetes.io/backend-protocol: "HTTPS"     # For HTTPS
```

### Pod Annotations
```yaml
# Force restart when config changes
checksum/config-map: 6e014813187035a5b7ea862a5fbda788af7071448d6fadd5bc32f23e9f03f291
checksum/secret: 95f9ddd4379bebbef3da1491ff67dba309f4d2bb2a4c41709c2bf46f57807157
```

### Storage Annotations
```yaml
volume.beta.kubernetes.io/storage-provisioner: "kubernetes.io/no-provisioner"
volume.kubernetes.io/storage-provisioner: fast-ssd
```

## Environment and Organization Labels

### Environment Classification
```yaml
environment: development|staging|production
team: data-science|engineering|research
cost-center: "12345"
```

### Monitoring and Alerting
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8888"
prometheus.io/path: "/metrics"
grafana.io/dashboard: "jupyterhub-overview"
alert.company.com/severity: critical|warning|info
```

### Security and Compliance
```yaml
security.company.com/scan-level: strict|standard|basic
compliance.company.com/required: "true"
audit.company.com/retention: "7years"
```

## Configuration Examples

### Production Environment
```yaml
global:
  environment: production
  team: data-science
  cost-center: "DS-12345"
  commonLabels:
    environment: production
    team: data-science
    cost-center: "DS-12345"
    monitoring.company.com/tier: critical
  commonAnnotations:
    contact: admin@company.com
    documentation: https://wiki.company.com/jupyterhub
    backup.company.com/schedule: "0 2 * * *"

hub:
  extraLabels:
    hub.jupyter.org/tier: critical
    monitoring.company.com/alert-level: high
  extraAnnotations:
    security.company.com/scan-level: strict
    compliance.company.com/required: "true"

proxy:
  extraLabels:
    proxy.jupyter.org/tier: gateway
    networking.company.com/zone: public
  extraAnnotations:
    loadbalancer.company.com/algorithm: round-robin
    networking.company.com/timeout: "30s"

singleuser:
  extraLabels:
    user.jupyter.org/tier: standard
    workload.company.com/type: interactive
  extraAnnotations:
    autoscaling.company.com/target-utilization: "80"
    backup.company.com/user-data: "enabled"
```

### Development Environment
```yaml
global:
  environment: development
  team: engineering
  commonLabels:
    environment: development
    team: engineering
    temporary: "true"
  commonAnnotations:
    contact: dev-team@company.com
    documentation: https://dev-wiki.company.com/jupyterhub
    
hub:
  extraLabels:
    hub.jupyter.org/tier: development
  extraAnnotations:
    security.company.com/scan-level: basic
```

## Resource Selection Examples

### kubectl Commands Using Labels

```bash
# Get all JupyterHub resources
kubectl get all -l app.kubernetes.io/name=my-jupyterhub

# Get only hub components
kubectl get all -l app.kubernetes.io/component=hub

# Get resources by environment
kubectl get all -l environment=production

# Get user workloads only
kubectl get pods -l jupyterhub.io/component-type=user-workload

# Get all critical tier resources
kubectl get all -l monitoring.company.com/tier=critical
```

### Prometheus Queries Using Labels

```promql
# CPU usage by component
sum(rate(container_cpu_usage_seconds_total[5m])) by (app_kubernetes_io_component)

# Memory usage by environment
sum(container_memory_usage_bytes) by (environment)

# User pod count by team
count(kube_pod_info{jupyterhub_io_component_type="user-workload"}) by (team)
```

### Network Policies Using Labels

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-hub-to-proxy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: proxy
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/component: hub
```

## Monitoring and Alerting Integration

### Prometheus ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jupyterhub
  labels:
    app.kubernetes.io/name: my-jupyterhub
spec:
  selector:
    matchLabels:
      prometheus.io/scrape: "true"
  endpoints:
  - port: http
    path: /metrics
```

### Grafana Dashboard Variables
```json
{
  "templating": {
    "list": [
      {
        "name": "environment",
        "label": "Environment",
        "query": "label_values(environment)"
      },
      {
        "name": "component",
        "label": "Component", 
        "query": "label_values(app_kubernetes_io_component)"
      }
    ]
  }
}
```

## Best Practices

### 1. Label Naming Conventions
- Use consistent prefixes: `jupyterhub.io/`, `hub.jupyter.org/`
- Follow DNS subdomain format for custom labels
- Use lowercase with hyphens for separation
- Keep labels concise but descriptive

### 2. Annotation Usage
- Use annotations for metadata that doesn't need to be selected
- Include URLs, contact information, and descriptive text
- Add operational metadata like backup schedules and monitoring configs
- Include change tracking information

### 3. Label Selection Strategy
- Plan label hierarchy for efficient querying
- Use consistent values across environments
- Avoid high-cardinality labels in monitoring contexts
- Document label meanings and usage

### 4. Security Considerations
- Don't include sensitive information in labels/annotations
- Use labels for network policy enforcement
- Include security scanning and compliance metadata
- Track resource ownership for audit purposes

### 5. Operational Integration
- Integrate with monitoring and alerting systems
- Use labels for automated operations (scaling, backup)
- Include cost allocation and chargeback metadata
- Support multi-tenant environments with proper labeling

This comprehensive labeling and annotation system ensures that your JupyterHub deployment is properly organized, monitored, secured, and operationally managed according to enterprise best practices.