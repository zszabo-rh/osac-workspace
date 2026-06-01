# MOC Development Environment (hypershift1)

Shared dev cluster at Mass Open Cloud. Each developer deploys their own OSAC instance in a dedicated namespace.

| Property | Value |
|----------|-------|
| Console | `https://console.apps.hypershift1.nerc.mghpcc.org` |
| API | `api.hypershift1.nerc.mghpcc.org:6443` |
| OpenShift | 4.18.x (3 control-plane + 3 workers) |

## Pre-installed Infrastructure

RHACM, HyperShift, OCP-Virt (KubeVirt), AAP Operator, Authorino, Cert-Manager, Ceph RBD/NFS/LVM storage, VM OS images (RHEL 7-10, Fedora, CentOS, Windows), 324 ClusterImageSets.

## Getting Access

1. Link GitHub account to Red Hat
2. PR to `github-config`: add username to `members.csv` and `team-members/fulfillment-wg.csv`
3. Auth via `osac-project` GitHub OAuth provider (restricted to `osac-project/fulfillment-wg`)

## RBAC (sudoer pattern)

`fulfillment-wg` group bound to `nerc-ops` ClusterRole:
- **Read**: direct access (no `--as` flag needed)
- **Write**: requires `--as system:admin` impersonation

```bash
# Read — direct
oc get pods -n innabox-lars
oc get hostedclusters --all-namespaces

# Write — impersonate
oc create namespace my-namespace --as system:admin
oc apply -k overlays/my-dev --as system:admin
```

## Existing Deployments

| Namespace | Description | Prefix |
|-----------|-------------|--------|
| `fulfillment-aap` | Shared/legacy stack | `fulfillment-` |
| `innabox-lars` | Developer stack (healthy) | `innabox-` |
| `innabox-demo` | Demo stack (partially broken) | `innabox-` |

## Bare Metal / ESI

HostPool CRD groups machines by host class (e.g., `fc430`, `h100`). ESI Ansible collection handles node provisioning via OpenStack Ironic APIs. Contact `@tzumainn` and `@larsks` in Slack for bare metal allocation. See `docs/importing-esi-nodes.md`.

Beaker hosts are NOT recommended for OSAC — full stack exceeds typical resources, and ESI is unavailable.
