# =============================================================================
# values.yaml — Default configuration values
# =============================================================================
# Override at install time with:
#   helm install myapp ./my-first-chart --set replicaCount=3
#   helm install myapp ./my-first-chart -f prod-values.yaml
# =============================================================================

replicaCount: 1

image:
  repository: nginx
  tag: "1.25-alpine"
  pullPolicy: IfNotPresent

imagePullSecrets: []

serviceAccount:
  create: true
  name: ""
  annotations: {}

podAnnotations: {}
podLabels: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - "ALL"

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 20

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10

volumes: []
volumeMounts: []

nodeSelector: {}
tolerations: []
affinity: {}

env:
  - name: NODE_ENV
    value: production
  - name: PORT
    value: "3000"

config:
  logLevel: info
  cacheTTL: "60"