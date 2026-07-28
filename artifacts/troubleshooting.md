# OSAC Troubleshooting

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `ImagePullBackOff` | Invalid registry credentials | Check pull secrets in namespace |
| Certificate errors | cert-manager not ready | Check cert-manager pods and issuer status |
| ClusterOrder stuck in Progressing | AAP job failed | Check AAP job logs in UI |
| gRPC connection refused | Service not running | Check fulfillment-service pods |
| OAuth login fails | Not in GitHub team | Verify team membership, wait for group-sync |

## Debug Commands

```bash
# Check ClusterOrder status
oc get clusterorder <name> -o yaml

# Check HostedCluster
oc get hostedcluster -n <cluster-namespace> -o yaml

# Check operator logs
oc logs deployment/<prefix>-controller-manager -n <namespace> --tail=200

# Check AAP job logs via AAP UI
oc get route -n <namespace> | grep aap

# Check certificate status
oc describe certificate -n <namespace>

# Check all events
oc get events -n <namespace> --sort-by=.metadata.creationTimestamp

# Check service endpoints
oc get endpoints -n <namespace>

# Get fulfillment service logs
oc logs -n <namespace> deployment/fulfillment-service -c server --tail=500

# Get operator logs
oc logs -n <namespace> deployment/<prefix>-controller-manager --tail=500

# Get AAP activation logs
oc logs -n <namespace> deployment/<prefix>-eda-activation --tail=500
```

## Rebuild and Redeploy Component

```bash
# Fulfillment service
cd fulfillment-service
podman build -t quay.io/myuser/fulfillment-service:dev .
podman push quay.io/myuser/fulfillment-service:dev
oc set image deployment/fulfillment-service server=quay.io/myuser/fulfillment-service:dev -n <namespace>

# Operator
cd osac-operator
make image-build image-push IMG=quay.io/myuser/osac-operator:dev
make deploy IMG=quay.io/myuser/osac-operator:dev
```

## Local Integration Environment

```bash
cd fulfillment-service

# Add hosts entries
echo '127.0.0.1 keycloak.keycloak.svc.cluster.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 fulfillment-api.osac.svc.cluster.local' | sudo tee -a /etc/hosts

# Setup environment without running tests
IT_KEEP_KIND=true ginkgo run --label-filter setup it

# Manual testing
kubectl get pods -A
grpcurl -plaintext -H "Authorization: Bearer $(kubectl create token client -n osac)" \
    fulfillment-api.osac.svc.cluster.local:8000 fulfillment.v1.ClusterTemplates/List
```
