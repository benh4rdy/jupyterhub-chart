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
Common labels
*/}}
{{- define "my-jupyterhub.labels" -}}
helm.sh/chart: {{ include "my-jupyterhub.chart" . }}
{{ include "my-jupyterhub.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-jupyterhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-jupyterhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Hub specific labels
*/}}
{{- define "my-jupyterhub.hub.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: hub
{{- end }}

{{- define "my-jupyterhub.hub.selectorLabels" -}}
{{ include "my-jupyterhub.selectorLabels" . }}
app.kubernetes.io/component: hub
{{- end }}

{{- define "my-jupyterhub.hub.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-hub
{{- end }}

{{/*
Proxy specific labels
*/}}
{{- define "my-jupyterhub.proxy.labels" -}}
{{ include "my-jupyterhub.labels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{- define "my-jupyterhub.proxy.selectorLabels" -}}
{{ include "my-jupyterhub.selectorLabels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{- define "my-jupyterhub.proxy-api.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-proxy-api
{{- end }}

{{- define "my-jupyterhub.proxy-public.fullname" -}}
{{ include "my-jupyterhub.fullname" . }}-proxy-public
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
Generate self-signed certificate for HTTPS (development/closed environment)
*/}}
{{- define "my-jupyterhub.selfSignedCert" -}}
{{- if .Values.proxy.https.selfSigned.enabled }}
{{- $ca := genCA .Values.proxy.https.selfSigned.organization .Values.proxy.https.selfSigned.validityDays }}
{{- $cert := genSignedCert .Values.proxy.https.selfSigned.commonName nil (list .Values.proxy.https.selfSigned.commonName) .Values.proxy.https.selfSigned.validityDays $ca }}
{{- $cert.Cert }}
{{- end }}
{{- end }}

{{/*
Generate self-signed key for HTTPS (development/closed environment)
*/}}
{{- define "my-jupyterhub.selfSignedKey" -}}
{{- if .Values.proxy.https.selfSigned.enabled }}
{{- $ca := genCA .Values.proxy.https.selfSigned.organization .Values.proxy.https.selfSigned.validityDays }}
{{- $cert := genSignedCert .Values.proxy.https.selfSigned.commonName nil (list .Values.proxy.https.selfSigned.commonName) .Values.proxy.https.selfSigned.validityDays $ca }}
{{- $cert.Key }}
{{- end }}
{{- end }}