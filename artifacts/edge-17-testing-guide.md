# Edge-17 Beaker Server Testing Guide

**Environment**: edge-17 beaker server (10.6.141.65) - SNO OCP cluster for OSAC testing  
**Last Updated**: 2026-09-17

## Quick Start

```bash
# SSH access
ssh -i ~/.ssh/beaker root@10.6.141.65

# On edge-17
export KUBECONFIG=/root/.kube/caas-dev.kubeconfig
export K8S_SERVER=https://192.168.162.10:6443
alias k='oc --server=$K8S_SERVER --insecure-skip-tls-verify'
```

⚠️ **IMPORTANT**: The `~/.ssh/config` alias `Host edge-17` points to a STALE FQDN that times out. Always use direct IP `10.6.141.65`.

---

## Environment Overview

### Cluster Details
- **OCP Version**: 4.19.32
- **Kubernetes**: v1.32.13
- **Topology**: Single-Node OpenShift (SNO)
- **Node**: test-infra-cluster-caas-dev-master-0
- **API**: https://192.168.162.10:6443 (internal libvirt network)
- **Kubeconfig**: `/root/.kube/caas-dev.kubeconfig`
- **Cluster Tool**: Flavor `caas`, clone `caas-dev`

### Network
- **Host IP**: 10.6.141.65 (accessible from laptop)
- **Cluster API**: 192.168.162.10:6443 (internal libvirt network)
- **Pod Network**: 172.30.0.0/16 (OVN)

**Access Pattern**: 
- From laptop: SSH to 10.6.141.65
- From edge-17: Access cluster via internal IP 192.168.162.10
- Kubeconfig's hostname doesn't resolve → use `--server=$K8S_SERVER --insecure-skip-tls-verify` on all oc commands

### OSAC Deployment

**Namespace**: `osac-e2e-ci`

**Core Services** (Running):
- fulfillment-grpc-server
- fulfillment-rest-gateway
- fulfillment-console-proxy
- fulfillment-controller
- osac-operator
- postgres
- keycloak

**AAP Stack** (Working after 2026-09-17 cleanup):
- osac-aap-controller-task ✅ (1/1) - provisions VMs/clusters
- osac-aap-controller-web ✅ (1/1) - API/UI
- osac-aap-gateway ✅ (1/1)
- osac-aap-eda-* ⚠️ - Event-Driven Ansible (partial, not needed for basic provisioning)

**Current Component Versions**:
- operator: `ghcr.io/osac-project/osac-operator:latest` (unknown age)
- fulfillment-service: `ghcr.io/osac-project/fulfillment-service:osac-4542-e2e` (old feature branch)

### LVMS Storage

**Hub Cluster**:
- LVMS installed in `openshift-storage` namespace
- LVMCluster: `lvms-cluster` (Ready)
- Default Channel: `stable-4.19`
- Storage Classes:
  - `lvms-vg1` (default, WaitForFirstConsumer)
  - `osac-e2e-test-local` (tenant-specific, topolvm.io provisioner)

### Tenants

```
e2e-test        (has storage: osac-e2e-test-local)
osac-e2e-ci     (no storage classes)
shared          (no storage classes)
system          (no storage classes)
```

---

## Common Operations

### Accessing the Cluster

```bash
# From laptop
ssh -i ~/.ssh/beaker root@10.6.141.65

# On edge-17, set up environment
export KUBECONFIG=/root/.kube/caas-dev.kubeconfig
export K8S_SERVER=https://192.168.162.10:6443
alias k='oc --server=$K8S_SERVER --insecure-skip-tls-verify'

# Test access
k get nodes
k get pods -n osac-e2e-ci
```

### Checking Component Status

```bash
# OSAC core services
k get pods -n osac-e2e-ci | grep -E 'fulfillment|osac-operator|postgres|keycloak'

# AAP status
k get deployment -n osac-e2e-ci | grep aap

# Component versions
k get deploy osac-operator -n osac-e2e-ci -o jsonpath="{.spec.template.spec.containers[0].image}"
k get deploy fulfillment-grpc-server -n osac-e2e-ci -o jsonpath="{.spec.template.spec.containers[0].image}"
```

### Viewing Logs

```bash
# Fulfillment service
k logs -n osac-e2e-ci deploy/fulfillment-grpc-server -f

# Operator
k logs -n osac-e2e-ci deploy/osac-operator -f

# AAP task controller
k logs -n osac-e2e-ci deploy/osac-aap-controller-task -c osac-aap-controller-task -f

# CSI driver
k logs -n osac-e2e-ci deploy/osac-csi-controller -f
k logs -n osac-e2e-ci daemonset/osac-csi-node -f
```

### Checking OSAC Resources

```bash
# Tenants
k get tenants -n osac-e2e-ci

# Storage backends
k get storagebackends -n osac-e2e-ci

# Storage tiers
k get storagetiers -n osac-e2e-ci

# Volumes
k get volumes -n osac-e2e-ci

# Compute instances (VMs)
k get computeinstances -n osac-e2e-ci

# Cluster orders (for CaaS)
k get clusterorders -n osac-e2e-ci
```

### LVMS Storage

```bash
# Check LVMS cluster
k get lvmcluster -n openshift-storage

# Check storage classes
k get sc

# Check logical volumes
k get logicalvolumes -A

# Check topolvm-node logs
k logs -n openshift-storage daemonset/topolvm-node -c topolvm-node --tail=50
```

---

## Deploying Updated Components

When testing a feature with code changes:

### 1. Build Images (on your laptop)

```bash
# In osac-workspace/osac
cd <component-dir>  # e.g., fulfillment-service, osac-operator, osac-csi-driver

# Build and push
TAG="<feature-name>"  # e.g., "osac-3702-test" or "pr-999"
make docker-build IMG=ghcr.io/YOUR-USERNAME/<component>:$TAG
make docker-push IMG=ghcr.io/YOUR-USERNAME/<component>:$TAG
```

### 2. Update Deployments (on edge-17)

```bash
# Fulfillment service (3 deployments)
k set image deployment/fulfillment-grpc-server \
  fulfillment-grpc-server=ghcr.io/YOUR-USERNAME/fulfillment-service:$TAG \
  -n osac-e2e-ci

k set image deployment/fulfillment-rest-gateway \
  fulfillment-rest-gateway=ghcr.io/YOUR-USERNAME/fulfillment-service:$TAG \
  -n osac-e2e-ci

k set image deployment/fulfillment-controller \
  fulfillment-controller=ghcr.io/YOUR-USERNAME/fulfillment-service:$TAG \
  -n osac-e2e-ci

# Operator
k set image deployment/osac-operator \
  manager=ghcr.io/YOUR-USERNAME/osac-operator:$TAG \
  -n osac-e2e-ci

# CSI driver
k set image deployment/osac-csi-controller \
  osac-csi=ghcr.io/YOUR-USERNAME/osac-csi-driver:$TAG \
  -n osac-e2e-ci

k set image daemonset/osac-csi-node \
  osac-csi=ghcr.io/YOUR-USERNAME/osac-csi-driver:$TAG \
  -n osac-e2e-ci

# Wait for rollouts
k rollout status deployment/osac-operator -n osac-e2e-ci
k rollout status deployment/fulfillment-grpc-server -n osac-e2e-ci
```

### 3. Verify Deployment

```bash
# Check pod status
k get pods -n osac-e2e-ci | grep -E 'fulfillment|osac-operator|osac-csi'

# Check logs for startup errors
k logs -n osac-e2e-ci deploy/osac-operator --tail=50
k logs -n osac-e2e-ci deploy/fulfillment-grpc-server --tail=50
```

---

## Testing Workflows

### Testing with Fulfillment API

```bash
# Get auth token (SA token method - robust)
TOKEN=$(k create token admin -n osac-e2e-ci)

# Test API call via curl (from edge-17)
# Note: Route must be resolved manually since hostname doesn't resolve
ROUTE=$(k get route fulfillment-api -n osac-e2e-ci -o jsonpath='{.spec.host}')
API_IP="192.168.162.10"  # Internal API IP

curl -sk --resolve $ROUTE:443:$API_IP \
  -H "Authorization: Bearer $TOKEN" \
  https://$ROUTE/api/fulfillment/v1/tenants

# Or use osac CLI (if installed)
export OSAC_API_TOKEN=$TOKEN
export OSAC_API_URL="https://$ROUTE"
osac tenant list
```

### Creating a ComputeInstance (VMaaS)

```bash
# Example: Create a VM with local storage
cat <<EOF | k apply -f -
apiVersion: osac.openshift.io/v1alpha1
kind: ComputeInstance
metadata:
  name: test-vm
  namespace: osac-e2e-ci
  annotations:
    osac.openshift.io/tenant: e2e-test
spec:
  # VM spec here
EOF

# Watch provisioning
k get computeinstance test-vm -n osac-e2e-ci -w

# Check logs
k logs -n osac-e2e-ci deploy/osac-aap-controller-task -c osac-aap-controller-task -f
```

### Testing Storage Provisioning

```bash
# Create a test PVC using OSAC storage class
cat <<EOF | k apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: osac-e2e-ci
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: osac-e2e-test-local
EOF

# Create consumer pod
cat <<EOF | k apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: osac-e2e-ci
spec:
  containers:
  - name: app
    image: registry.access.redhat.com/ubi8/ubi-minimal:latest
    command: ["/bin/sh", "-c", "while true; do echo test; sleep 30; done"]
    volumeMounts:
    - mountPath: /data
      name: storage
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Watch provisioning
k get pvc test-pvc -n osac-e2e-ci -w
k get pod test-pod -n osac-e2e-ci -w

# Check Volume CR on hub
k get volumes -n osac-e2e-ci

# Check LogicalVolume CR
k get logicalvolumes -A
```

---

## Troubleshooting

### AAP Not Working

**Symptoms**: AAP pods in ContainerStatusUnknown or CrashLoopBackOff

**Root Cause**: Usually disk pressure eviction or stale pods after cluster cold boot

**Fix**:
```bash
# Delete stuck AAP task pods
k delete pods -n osac-e2e-ci -l app.kubernetes.io/name=osac-aap-controller-task

# Delete EDA worker pods (if needed)
k delete pods -n osac-e2e-ci -l app.kubernetes.io/component=eda-activation-worker
k delete pods -n osac-e2e-ci -l app.kubernetes.io/component=eda-default-worker
k delete pods -n osac-e2e-ci -l app.kubernetes.io/component=eda-scheduler

# Force delete if stuck
k get pods -n osac-e2e-ci -l <selector> -o name | \
  xargs k delete -n osac-e2e-ci --grace-period=0 --force

# Wait for deployments to recreate
k get deploy -n osac-e2e-ci | grep aap

# Verify task controller is running
k logs -n osac-e2e-ci deploy/osac-aap-controller-task -c osac-aap-controller-task --tail=20
```

**Essential AAP Components** (must be Running):
- `osac-aap-controller-task` - provisions VMs/clusters
- `osac-aap-controller-web` - API/UI

**Optional Components** (can be broken):
- `osac-aap-eda-*` - Event-Driven Ansible (not needed for basic provisioning)

### Disk Pressure

**Check Node Conditions**:
```bash
k describe node test-infra-cluster-caas-dev-master-0 | grep -A 10 Conditions
```

**If DiskPressure=True**:
```bash
# Check disk usage
df -h /

# Prune container images (on the node)
crictl rmi --prune

# Clean up old pods
k delete pods -n osac-e2e-ci --field-selector=status.phase=Failed
k delete pods -n osac-e2e-ci --field-selector=status.phase=Succeeded
```

### API Access Issues

**Symptom**: `dial tcp: no route to host` or DNS resolution failures

**Fix**: Always use `--server=$K8S_SERVER --insecure-skip-tls-verify` with oc commands

```bash
# Set environment
export K8S_SERVER=https://192.168.162.10:6443

# Use explicit server flag
oc --server=$K8S_SERVER --insecure-skip-tls-verify get nodes

# Or create alias
alias k='oc --server=$K8S_SERVER --insecure-skip-tls-verify'
```

### Component Logs Show Errors

```bash
# Check recent events
k get events -n osac-e2e-ci --sort-by='.lastTimestamp' | tail -20

# Check pod describe
k describe pod <pod-name> -n osac-e2e-ci

# Check container logs
k logs <pod-name> -n osac-e2e-ci -c <container-name> --tail=100

# Check previous container logs (if pod restarted)
k logs <pod-name> -n osac-e2e-ci -c <container-name> --previous
```

### Libvirt VMs

```bash
# List all VMs
virsh list --all

# Start a VM
virsh start <vm-name>

# Stop a VM
virsh shutdown <vm-name>
virsh destroy <vm-name>  # Force stop

# VM console
virsh console <vm-name>

# Check VM disks
virsh domblklist <vm-name>

# VM info
virsh dominfo <vm-name>
```

---

## Environment Maintenance

### Reverting to Stable Images

After testing, reset to upstream images:

```bash
k set image deployment/osac-operator \
  manager=ghcr.io/osac-project/osac-operator:latest \
  -n osac-e2e-ci

k set image deployment/fulfillment-grpc-server \
  fulfillment-grpc-server=ghcr.io/osac-project/fulfillment-service:latest \
  -n osac-e2e-ci

# Repeat for other components
```

### Cleaning Up Test Resources

```bash
# Delete test pods/PVCs
k delete pod test-pod -n osac-e2e-ci
k delete pvc test-pvc -n osac-e2e-ci

# Delete test compute instances
k delete computeinstance test-vm -n osac-e2e-ci

# Delete test cluster orders
k delete clusterorder <name> -n osac-e2e-ci
```

### Cluster Health Check

```bash
# Node status
k get nodes

# Pod health
k get pods -A | grep -v Running | grep -v Completed

# Check critical namespaces
k get pods -n osac-e2e-ci
k get pods -n openshift-storage
k get pods -n kube-system

# Check cluster operators (if OCP)
oc get clusteroperators
```

---

## Known Issues and Limitations

### 1. AAP Fragility
- AAP pods often crash after cluster cold boot
- Usually recoverable by deleting stuck pods
- EDA components (scheduler, workers) are flaky but not critical

### 2. Disk Space
- Node historically runs ~83% full
- Evictions happen when ephemeral storage crosses threshold
- Regular image pruning recommended

### 3. Network Access
- Cluster API only reachable from edge-17 host
- Kubeconfig hostnames don't resolve → use `--server` flag
- Routes require manual IP resolution

### 4. Component Versions
- Current deployment has mix of versions
- Always check and update before testing
- Old feature branch images may be present

### 5. Single Node Limitations
- SNO = no HA, single point of failure
- Limited resources for nested clusters
- Disk space constraints

---

## Quick Reference

### Environment Variables

```bash
export KUBECONFIG=/root/.kube/caas-dev.kubeconfig
export K8S_SERVER=https://192.168.162.10:6443
export OSAC_NS=osac-e2e-ci
```

### Useful Aliases

```bash
alias k='oc --server=$K8S_SERVER --insecure-skip-tls-verify'
alias kns='k get pods -n $OSAC_NS'
alias klogs='k logs -n $OSAC_NS'
```

### Key Paths

- Kubeconfig: `/root/.kube/caas-dev.kubeconfig`
- Cluster Tool: `/usr/local/bin/cluster-tool`
- Overlays: `/home/cluster-tool/overlays/`
- Libvirt Images: `/var/lib/libvirt/images/`

### Important IPs

- Host: 10.6.141.65
- Cluster API: 192.168.162.10:6443
- Pod Network: 172.30.0.0/16

---

**Last Verified**: 2026-09-17  
**Status**: Environment accessible, AAP working, LVMS ready
