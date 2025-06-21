{{/*
Expand the name of the chart.
*/}}
{{- define "my-jupyterhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-jupyterhub.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "my-jupyterhub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - Applied to all resources
*/}}
{{- define "my-jupyterhub.labels" -}}
helm.sh/chart: {{ include "my-jupyterhub.chart" . }}
{{ include "my-jupyterhub.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: jupyterhub
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels - Used for resource selection
*/}}
{{- define "my-jupyterhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-jupyterhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations - Applied to all resources
*/}}
{{- define "my-jupyterhub.annotations" -}}
meta.helm.sh/release-name: {{ .Release.Name }}
meta.helm.sh/release-namespace: {{ .Release.Namespace }}
jupyterhub.io/chart-version: {{ .Chart.Version }}
jupyterhub.io/app-version: {{ .Chart.AppVersion }}
{{- if .Values.global.commonAnnotations }}
{{- toYaml .Values.global.commonAnnotations | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Hub specific labels
*/}}
{{- define "my-jupyterhub.hub.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: hub
jupyterhub.io/component-type: control-plane
{{- with .Values.hub.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Hub selector labels
*/}}
{{- define "my-jupyterhub.hub.selectorLabels" -}}
{{ include "my-jupyterhub.selectorLabels" . }}
app.kubernetes.io/component: hub
{{- end }}

{{/*
Hub annotations
*/}}
{{- define "my-jupyterhub.hub.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: hub
jupyterhub.io/network-access-required: "proxy-api,proxy-http,singleuser"
{{- with .Values.hub.extraAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Hub fullname
*/}}
{{- define "my-jupyterhub.hub.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-hub
{{- end }}

{{/*
Proxy specific labels
*/}}
{{- define "my-jupyterhub.proxy.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: proxy
jupyterhub.io/component-type: gateway
{{- with .Values.proxy.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Proxy selector labels
*/}}
{{- define "my-jupyterhub.proxy.selectorLabels" -}}
{{ include "my-jupyterhub.selectorLabels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{/*
Proxy annotations
*/}}
{{- define "my-jupyterhub.proxy.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: proxy
jupyterhub.io/network-access-required: "hub,external"
{{- with .Values.proxy.extraAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Proxy API service fullname
*/}}
{{- define "my-jupyterhub.proxy-api.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-proxy-api
{{- end }}

{{/*
Proxy public service fullname
*/}}
{{- define "my-jupyterhub.proxy-public.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-proxy-public
{{- end }}

{{/*
Singleuser specific labels
*/}}
{{- define "my-jupyterhub.singleuser.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: singleuser-server
jupyterhub.io/component-type: user-workload
{{- with .Values.singleuser.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Singleuser annotations
*/}}
{{- define "my-jupyterhub.singleuser.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: singleuser
jupyterhub.io/network-access-required: "hub,proxy"
{{- with .Values.singleuser.extraAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for hub
*/}}
{{- define "my-jupyterhub.hub.serviceAccountName" -}}
{{- if .Values.hub.serviceAccount.create }}
{{- default (include "my-jupyterhub.hub.fullname" .) .Values.hub.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.hub.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate the secret token if not provided
*/}}
{{- define "my-jupyterhub.proxy.secretToken" -}}
{{- if .Values.proxy.secretToken }}
{{- .Values.proxy.secretToken }}
{{- else }}
{{- randAlphaNum 32 | b64enc }}
{{- end }}
{{- end }}

{{/*
Network Policy labels for pod communication
*/}}
{{- define "my-jupyterhub.networkPolicy.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: network-policy
jupyterhub.io/component-type: security
{{- end }}

{{/*
Monitoring labels for observability
*/}}
{{- define "my-jupyterhub.monitoring.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: monitoring
jupyterhub.io/component-type: observability
{{- if .Values.monitoring.prometheus.enabled }}
prometheus.io/scrape: "true"
{{- end }}
{{- end }}

{{/*
Storage labels for persistent volumes
*/}}
{{- define "my-jupyterhub.storage.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: storage
jupyterhub.io/component-type: persistence
{{- end }}

{{/*
RBAC labels for security resources
*/}}
{{- define "my-jupyterhub.rbac.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: rbac
jupyterhub.io/component-type: security
{{- end }}

{{/*
Configuration labels for ConfigMaps and Secrets
*/}}
{{- define "my-jupyterhub.config.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: configuration
jupyterhub.io/component-type: config
{{- end }}

{{/*
Generate deployment annotations with resource tracking
*/}}
{{- define "my-jupyterhub.deployment.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
deployment.kubernetes.io/revision: "1"
jupyterhub.io/resource-type: deployment
{{- if .Values.monitoring.prometheus.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/metrics"
{{- end }}
{{- end }}

{{/*
Generate pod annotations with networking and monitoring
*/}}
{{- define "my-jupyterhub.pod.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: pod
cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
{{- if .Values.monitoring.prometheus.enabled }}
prometheus.io/scrape: "true"
{{- end }}
{{- if .Values.security.networkPolicy.enabled }}
network-policy.kubernetes.io/ingress: "restricted"
network-policy.kubernetes.io/egress: "restricted"
{{- end }}
{{- end }}

{{/*
Generate service annotations with load balancer and networking
*/}}
{{- define "my-jupyterhub.service.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: service
{{- if eq .Values.proxy.service.type "LoadBalancer" }}
service.beta.kubernetes.io/external-traffic: "OnlyLocal"
{{- end }}
{{- if .Values.proxy.https.enabled }}
service.beta.kubernetes.io/backend-protocol: "HTTPS"
{{- end }}
{{- end }}

{{/*
Generate PVC annotations with storage metadata
*/}}
{{- define "my-jupyterhub.pvc.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: persistent-volume-claim
volume.beta.kubernetes.io/storage-provisioner: "kubernetes.io/no-provisioner"
{{- if .Values.persistence.storageClass }}
volume.kubernetes.io/storage-provisioner: {{ .Values.persistence.storageClass }}
{{- end }}
{{- end }}

{{/*
Generate secret annotations with security metadata
*/}}
{{- define "my-jupyterhub.secret.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: secret
kubernetes.io/managed-by: "Helm"
{{- end }}

{{/*
Generate ConfigMap annotations with configuration metadata
*/}}
{{- define "my-jupyterhub.configmap.annotations" -}}
{{ include "my-jupyterhub.annotations" . }}
jupyterhub.io/resource-type: configmap
kubernetes.io/managed-by: "Helm"
{{- end }}

{{/*
Generate resource owner labels for tracking relationships
*/}}
{{- define "my-jupyterhub.owner.labels" -}}
jupyterhub.io/owned-by: {{ .Release.Name }}
jupyterhub.io/managed-by: helm
jupyterhub.io/created-by: {{ .Chart.Name }}
{{- end }}

{{/*
Generate resource lifecycle annotations
*/}}
{{- define "my-jupyterhub.lifecycle.annotations" -}}
jupyterhub.io/created-at: {{ now | date "2006-01-02T15:04:05Z" | quote }}
jupyterhub.io/helm-revision: {{ .Release.Revision | quote }}
{{- if .Release.IsUpgrade }}
jupyterhub.io/upgraded-at: {{ now | date "2006-01-02T15:04:05Z" | quote }}
{{- end }}
{{- end }}

{{/*
Generate environment-specific labels
*/}}
{{- define "my-jupyterhub.environment.labels" -}}
{{- if .Values.global.environment }}
environment: {{ .Values.global.environment }}
{{- end }}
{{- if .Values.global.team }}
team: {{ .Values.global.team }}
{{- end }}
{{- if .Values.global.cost-center }}
cost-center: {{ index .Values.global "cost-center" }}
{{- end }}
{{- end }}

{{/*
Generate self-signed certificate for HTTPS (development/closed environment)
*/}}
{{- define "my-jupyterhub.selfSignedCert" -}}
{{- if .Values.proxy.https.selfSigned.enabled }}
{{- $altNames := list }}
{{- range .Values.proxy.https.hosts }}
{{- $altNames = append $altNames . }}
{{- end }}
{{- if .Values.proxy.https.selfSigned.altNames }}
{{- $altNames = concat $altNames .Values.proxy.https.selfSigned.altNames }}
{{- end }}
{{- $ca := genCA (.Values.proxy.https.selfSigned.caCommonName | default "JupyterHub CA") (.Values.proxy.https.selfSigned.validityDays | default 365) }}
{{- $cert := genSignedCert (.Values.proxy.https.selfSigned.commonName | default "jupyter.local") nil $altNames (.Values.proxy.https.selfSigned.validityDays | default 365) $ca }}
{{- $cert.Cert }}
{{- end }}
{{- end }}

{{/*
Generate self-signed key for HTTPS (development/closed environment)
*/}}
{{- define "my-jupyterhub.selfSignedKey" -}}
{{- if .Values.proxy.https.selfSigned.enabled }}
{{- $altNames := list }}
{{- range .Values.proxy.https.hosts }}
{{- $altNames = append $altNames . }}
{{- end }}
{{- if .Values.proxy.https.selfSigned.altNames }}
{{- $altNames = concat $altNames .Values.proxy.https.selfSigned.altNames }}
{{- end }}
{{- $ca := genCA (.Values.proxy.https.selfSigned.caCommonName | default "JupyterHub CA") (.Values.proxy.https.selfSigned.validityDays | default 365) }}
{{- $cert := genSignedCert (.Values.proxy.https.selfSigned.commonName | default "jupyter.local") nil $altNames (.Values.proxy.https.selfSigned.validityDays | default 365) $ca }}
{{- $cert.Key }}
{{- end }}
{{- end }}

{{/*
Hub Resource Configuration
*/}}
{{- define "my-jupyterhub.hub.resources" -}}
{{- if .Values.hub.resources }}
resources:
  {{- if .Values.hub.resources.requests }}
  requests:
    {{- if .Values.hub.resources.requests.cpu }}
    cpu: {{ .Values.hub.resources.requests.cpu | quote }}
    {{- end }}
    {{- if .Values.hub.resources.requests.memory }}
    memory: {{ .Values.hub.resources.requests.memory | quote }}
    {{- end }}
  {{- end }}
  {{- if .Values.hub.resources.limits }}
  limits:
    {{- if .Values.hub.resources.limits.cpu }}
    cpu: {{ .Values.hub.resources.limits.cpu | quote }}
    {{- end }}
    {{- if .Values.hub.resources.limits.memory }}
    memory: {{ .Values.hub.resources.limits.memory | quote }}
    {{- end }}
  {{- end }}
{{- else }}
# Default hub resources if not specified
resources:
  requests:
    cpu: "200m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
{{- end }}
{{- end }}

{{/*
Proxy Resource Configuration
*/}}
{{- define "my-jupyterhub.proxy.resources" -}}
{{- if .Values.proxy.chp.resources }}
resources:
  {{- if .Values.proxy.chp.resources.requests }}
  requests:
    {{- if .Values.proxy.chp.resources.requests.cpu }}
    cpu: {{ .Values.proxy.chp.resources.requests.cpu | quote }}
    {{- end }}
    {{- if .Values.proxy.chp.resources.requests.memory }}
    memory: {{ .Values.proxy.chp.resources.requests.memory | quote }}
    {{- end }}
  {{- end }}
  {{- if .Values.proxy.chp.resources.limits }}
  limits:
    {{- if .Values.proxy.chp.resources.limits.cpu }}
    cpu: {{ .Values.proxy.chp.resources.limits.cpu | quote }}
    {{- end }}
    {{- if .Values.proxy.chp.resources.limits.memory }}
    memory: {{ .Values.proxy.chp.resources.limits.memory | quote }}
    {{- end }}
  {{- end }}
{{- else }}
# Default proxy resources if not specified
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "1000m"
    memory: "512Mi"
{{- end }}
{{- end }}

{{/*
Get the certificate secret name
*/}}
{{- define "my-jupyterhub.https.secretName" -}}
{{- if eq .Values.proxy.https.type "secret" }}
{{- .Values.proxy.https.secret.name | default (printf "%s-https-cert" (include "my-jupyterhub.fullname" .)) }}
{{- else }}
{{- printf "%s-https-cert" (include "my-jupyterhub.fullname" .) }}
{{- end }}
{{- end }}