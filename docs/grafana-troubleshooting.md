Incident 003 — Grafana Login Failures and OOMKilled Restarts
Context
Platform: Amazon EKS (platform-dev-eks), namespace monitoring
Deployment: kube-prometheus-stack managed through Argo CD and Helm
Status: Grafana login recovered and dashboard viewed successfully; dashboard provisioning log warnings require a separate follow-up.
Symptoms
- Grafana login was unsuccessful or returned to the login screen shortly after authentication.
- The Grafana pod's main container had restarted with reason OOMKilled.
- After a Helm values change, the monitoring Argo CD Application temporarily showed OutOfSync.
Investigation
1. Check the Grafana Service and port-forward
kubectl get svc -n monitoring monitoring-grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
Open http://localhost:3000 in a browser.
2. Retrieve the actual admin credentials
kubectl get secret monitoring-grafana -n monitoring \
  -o jsonpath='{.data.admin-user}' | base64 --decode; echo
kubectl get secret monitoring-grafana -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 --decode; echo
admin-user and admin-password are Secret data keys, not necessarily the literal login credentials. Base64 decoding reveals the stored values; Base64 is not encryption. Do not commit credentials or paste them into incident reports.
3. Separate credential errors from application instability
With the port-forward active, test Grafana's API:
read -r -p 'Grafana username: ' GRAFANA_USER
read -r -s -p 'Grafana password: ' GRAFANA_PASSWORD; echo
curl -sS -o /dev/null -w '%{http_code}\n' \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  http://localhost:3000/api/org
unset GRAFANA_PASSWORD
Observed: HTTP 200. The credentials worked, so the investigation moved to Grafana runtime health. A successful API response alone does not prove that browser sessions are stable.
4. Inspect pod restarts and termination reason
kubectl get pods -n monitoring
kubectl describe pod -n monitoring <grafana-pod-name>
kubectl logs -n monitoring <grafana-pod-name> -c grafana --previous
Observed: Grafana's main container was OOMKilled (out of memory). The earlier resource settings were:
- Memory request: 128Mi
- Memory limit: 256Mi
Resolution
Updated Grafana resources in helm/monitoring/values.yaml:
grafana:
  resources:
    requests:
      memory: 256Mi
    limits:
      memory: 512Mi
This excerpt shows the memory settings relevant to the incident, not necessarily the complete Grafana values configuration.

Committed and pushed the change so Argo CD could reconcile the monitoring release.
Secondary issue: invalid resource request
A typo set the request to 2568Mi, exceeding the 512Mi memory limit. The resulting configuration could not be applied successfully and the Argo CD Application was OutOfSync.

Corrected the request to 256Mi, pushed the fix, and refreshed the Application in Argo CD. The Application returned to Synced and Grafana login subsequently succeeded.
Verification
- [x] Grafana API accepted the configured credentials (HTTP 200).
- [x] Corrected Helm values were synchronized through Argo CD.
- [x] Browser login succeeded.
- [x] Grafana dashboard was opened and visually checked.
- [ ] Verify Grafana has remained free of further OOM restarts across a longer observation window.
- [ ] Confirm all dashboard provisioning warnings are resolved.
Useful follow-up checks:
kubectl get pods -n monitoring
kubectl describe pod -n monitoring <grafana-pod-name>
kubectl get applications -n argocd
Separate follow-up: dashboard provisioning warnings
During troubleshooting, Grafana logs reported a missing directory:
/var/lib/grafana/dashboards/default: no such file or directory
The dashboard sidecar was configured to use /tmp/dashboards. Even though the dashboard later appeared, the warning should be investigated separately rather than assumed resolved. Compare the dashboard provider path, sidecar folder setting, mounted ConfigMaps, and Grafana provisioning logs.
Lessons learned
1. A login loop can be caused by pod instability, not just incorrect credentials.
2. Test API authentication separately from browser login to narrow the cause.
3. Inspect kubectl describe pod and previous container logs for OOMKilled.
4. Kubernetes memory requests must not exceed memory limits.
5. Validate Helm values before pushing changes; Argo CD sync state helps reveal configuration failures.
6. Record confirmed fixes separately from warnings that still need investigation.
Related project files
- helm/monitoring/values.yaml
- gitops/argocd/applications/monitoring.yaml
- docs/monitoring.md
- docs/architecture.md