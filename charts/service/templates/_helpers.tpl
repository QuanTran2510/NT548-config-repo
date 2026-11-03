{{- define "service.name" -}}
{{- required "values.service is required (set by envs/<service>-<site>/values.yaml)" .Values.service -}}
{{- end -}}

{{- define "service.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ include "service.fullname" . }}
{{- end -}}

{{- define "service.labels" -}}
{{ include "service.selectorLabels" . }}
app.kubernetes.io/managed-by: argocd
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "service.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $tag := required "image.tag is required" .Values.image.tag | toString -}}
{{- if eq $tag "latest" -}}{{- fail "image.tag must not be 'latest'" -}}{{- end -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
