# OSAC Provisioning Workflow

## Cluster Provisioning Flow

1. **User** submits request via CLI/UI
2. **Fulfillment Service** validates request, selects Hub, creates `ClusterOrder` CR
3. **OSAC Operator** reconciles ClusterOrder:
   - Creates namespace, service account, RBAC
   - Triggers AAP automation (webhook or REST)
4. **AAP** executes template:
   - Creates `HostedCluster` (HyperShift)
   - Creates `NodePool` resources
   - Configures networking
5. **Operator** monitors HostedCluster status, updates ClusterOrder
6. **User** retrieves kubeconfig when ready

## AAP Integration Models

### EDA Provider (Legacy)
- Fire-and-forget webhooks
- Playbook manages finalizers
- Completion via annotation watch
- No job status visibility

### AAP Direct Provider (Recommended)
- REST API with job tracking
- Operator manages finalizers
- Real-time status polling
- Job cancellation support
- Crash recovery via persisted job IDs

## Authentication & Access Control

### OpenShift Clusters
- GitHub OAuth identity provider
- Team-based RBAC (e.g., `osac-project/fulfillment-wg`)
- group-sync-operator syncs GitHub teams to OpenShift groups

### Fulfillment Service
- OAuth2/OIDC (Keycloak)
- Bearer token authentication
- Service accounts for inter-component communication

### GitHub Organization (github-config)
- OpenTofu-managed org settings
- Team-based repository access
- Branch protection rules
- Member management via CSV files

## Environment-Specific Configuration

### Cluster Overlays (managed-cluster-config)

| Environment | Purpose |
|-------------|---------|
| `hypershift1` | HyperShift dev/staging |
| `nerc-ocp-infra` | NERC infrastructure |
| `nerc-ocp-prod` | Production |
| `nerc-ocp-test` | Testing |
