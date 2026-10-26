Monitoring and Alerting — AWS EKS Platform
1. Purpose and status
Status: Implemented and tested. This document records the observability stack deployed in the EKS development environment. The cluster is a temporary, cost-controlled lab, not a continuously operated production service.

The monitoring flow is:
FastAPI (/metrics)
   |
   v
Kubernetes Service (platform-api:8000)
   |
   v
ServiceMonitor (release: monitoring)
   |
   v
Prometheus (scrapes every 30 seconds)
   |                         \
   v                          v
Grafana dashboards       Prometheus alert rules
2. Components and configuration
Component	Implementation
Monitoring distribution	prometheus-community/kube-prometheus-stack Helm chart, version 92.13.1
Deployment management	Argo CD multi-source Application: gitops/argocd/applications/monitoring.yaml
Helm overrides	helm/monitoring/values.yaml
Namespace	monitoring
FastAPI instrumentation	prometheus-fastapi-instrumentator in apps/platform-api/main.py
API Service	platform-api, port 8000, namespace default
ServiceMonitor	Selects the FastAPI Service, labeled release: monitoring, 30-second scrape interval
Grafana dashboard definition	helm/monitoring/dashboards/fastapi.json
Dashboard ConfigMap	gitops/monitoring/fastapi-dashboard-configmap.yaml with grafana_dashboard: "1"
Alert rules	gitops/monitoring/fastapi-alerts.yaml (PrometheusRule, label release: monitoring)


The monitoring Argo CD Applications (monitoring and monitoring-dashboards) were observed Synced and Healthy during testing.
3. Access locally
The monitoring services are internal; use port-forwarding instead of exposing administrative dashboards publicly.

Prometheus:
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
Open http://localhost:9090.

Grafana (in a separate terminal):
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
Open http://localhost:3000. The username is usually admin; obtain the configured values from the Kubernetes Secret:
kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-user}' | base64 --decode; echo
kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 --decode; echo
Treat the password as sensitive; do not paste it into commits or screenshots. Base64 decoding is not decryption.

FastAPI (in another terminal):
kubectl port-forward -n default svc/platform-api 8000:8000
Open http://localhost:8000/health or http://localhost:8000/metrics.
4. Prometheus validation
The following queries were used during testing:
up{namespace="default",service="platform-api"}
Observed: 1, meaning the target was reachable and being scraped.
http_requests_total{namespace="default",service="platform-api"}
Observed: series for /health and /metrics.

To generate requests:
for i in {1..20}; do curl -s http://localhost:8000/ > /dev/null; done
Then query:
http_requests_total{handler="/"}
Observed: a value of 20 after the test, confirming the HTTP counter increased.

For request rate, generate requests over time rather than in one burst, then query:
sum(rate(http_requests_total{service="platform-api"}[5m]))
A rate can show 0 when there has been no recent traffic or the request burst was not captured between scrapes. A nonzero rate was not separately confirmed in the recorded test.

For mean request duration (seconds), if the histogram metrics are available:
sum(rate(http_request_duration_seconds_sum{service="platform-api"}[5m]))
/
sum(rate(http_request_duration_seconds_count{service="platform-api"}[5m]))
Inspect the actual metric labels before adapting these queries to other workloads.
5. Grafana dashboard
The FastAPI dashboard was opened and visually checked. It includes panels for:
- Requests per second
- HTTP 5xx error rate
- Average response latency
A historical dashboard provisioning log showed a path mismatch: Grafana referenced /var/lib/grafana/dashboards/default, while the dashboard sidecar wrote to /tmp/dashboards. This may be relevant if dashboards disappear after a rebuild; the log issue has not been independently confirmed resolved.

Useful checks:
kubectl get pods -n monitoring
kubectl get configmaps -n monitoring -l grafana_dashboard=1
kubectl logs -n monitoring deploy/monitoring-grafana -c grafana --tail=100
Check dashboard query labels and the configured Prometheus datasource if panels show no data.
6. Alerting rules
The following Prometheus alert rules were loaded and visible during validation:
Alert	Intent
FastAPIDown	FastAPI scrape target is unavailable
FastAPIHighErrorRate	Elevated HTTP 5xx error rate
FastAPIHighLatency	Elevated response latency


The rules are defined in gitops/monitoring/fastapi-alerts.yaml. Their presence in Prometheus was verified; firing and notification delivery were not tested. An inactive alert is normal while the service is healthy.
7. Troubleshooting lessons
Grafana login issues initially looked like bad credentials. An API authentication test returned HTTP 200, and investigation found Grafana had restarted due to OOMKilled with a 256Mi memory limit. Grafana's resources were increased in helm/monitoring/values.yaml to a 256Mi request and 512Mi limit. A temporary typo (2568Mi) caused Argo CD to report OutOfSync because the request exceeded the limit. After correction and synchronization, Grafana login worked.

See docs/grafana-troubleshooting.md (to be created) for the incident walkthrough.
8. Remaining validation
- [x] Prometheus FastAPI target reports up = 1
- [x] HTTP request counters increment
- [x] Grafana dashboard opens
- [x] Three alert rules are loaded
- [ ] Validate alert firing and notification routing
- [ ] Recheck dashboard provisioning after a fresh rebuild
- [ ] Test sustained request rate and latency under controlled load
- [ ] Review retention, resource usage, and security settings before any production use
9. Cost and teardown
Do not leave EKS, worker nodes, NAT gateways, or other chargeable AWS infrastructure running solely to keep the dashboard online. Before teardown, inspect PersistentVolumes and any retained EBS volumes; a Retain reclaim policy can leave storage resources billable after the Kubernetes claim or cluster is deleted. Confirm actual AWS resource cleanup and billing separately from terraform destroy.