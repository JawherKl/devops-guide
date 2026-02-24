{{- define "multi-service-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "multi-service-app.web.fullname" -}}
{{- printf "%s-web" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "multi-service-app.web.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}-web
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web
{{- end }}

{{- define "multi-service-app.api.fullname" -}}
{{- printf "%s-api" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "multi-service-app.api.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: api
{{- end }}

{{- define "multi-service-app.db.fullname" -}}
{{- printf "%s-db" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "multi-service-app.db.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}-db
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{- define "multi-service-app.db.secretName" -}}
{{- printf "%s-db-secret" .Release.Name }}
{{- end }}

{{- define "multi-service-app.db.host" -}}
{{- printf "%s-db" .Release.Name }}
{{- end }}