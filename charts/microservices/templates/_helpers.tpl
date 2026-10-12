{{/*
Common labels applied to all resources
*/}}
{{- define "microservices.labels" -}}
app.kubernetes.io/managed-by: Helm
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Build full ECR image URL
Usage: {{ include "microservices.image" (dict "registry" .Values.global.ecrRegistry "repo" .Values.backend.image "tag" .Values.global.imageTag) }}
*/}}
{{- define "microservices.image" -}}
{{ .registry }}/{{ .repo }}:{{ .tag }}
{{- end }}

{{/*
Common OTEL environment variables
Usage: {{ include "microservices.otelEnv" (dict "serviceName" "backend" "Values" .Values) }}
*/}}
{{- define "microservices.otelEnv" -}}
- name: OTEL_SERVICE_NAME
  value: {{ .serviceName | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.otel.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.otel.protocol | quote }}
- name: OTEL_METRICS_EXPORTER
  value: {{ .Values.otel.metricsExporter | quote }}
- name: OTEL_TRACES_EXPORTER
  value: {{ .Values.otel.tracesExporter | quote }}
- name: OTEL_LOGS_EXPORTER
  value: {{ .Values.otel.logsExporter | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "deployment.environment=production,service.version=1.0"
- name: OTEL_INSTRUMENTATION_MICROMETER_ENABLED
  value: "true"
{{- end }}
