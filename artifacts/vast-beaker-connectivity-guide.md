# Connecting a Beaker Server to the VAST Appliance

## Network Layout

```
Beaker server (e.g., 10.1.178.26)
  └── SSH tunnel ──→ VAST jump host (centos@10.46.83.88)
                       └── VAST management: 10.46.83.88:443
                       └── VAST VIPs: 11.0.0.2-3 (NFS/NVMe on internal Docker bridge)
```

The VAST appliance runs in a vSphere VM. Its management port (443) is on the Red Hat lab network (`10.46.83.88`), but NFS data ports use VIP addresses (`11.0.0.x`) on an internal Docker bridge — not directly routable. An SSH tunnel bridges both.

## Prerequisites

- The VAST appliance must be running (admin UI at `https://10.46.83.88:443`, creds: admin/123456).
- VAST jump host: `centos@10.46.83.88`, password: `centos`

## Step 1: Set up SSH key for the tunnel

The tunnel runs in the background (`-fN`), so it needs non-interactive auth. Run this on the beaker server:

```bash
sudo ssh-keygen -t ed25519 -C vast-tunnel -f /root/.ssh/vast -N ""
sudo ssh-copy-id -i /root/.ssh/vast.pub centos@10.46.83.88   # password: centos
```

## Step 2: Start the SSH tunnel

This forwards VAST management (443) and NFS data ports (2049, 20048, 4420) from the beaker server to the VAST appliance via the jump host:

```bash
sudo ssh -i /root/.ssh/vast -o StrictHostKeyChecking=no -fN \
  -L <BEAKER_IP>:8443:10.46.83.88:443 \
  -L <BEAKER_IP>:2049:11.0.0.2:2049 \
  -L <BEAKER_IP>:20048:11.0.0.2:20048 \
  -L <BEAKER_IP>:4420:11.0.0.2:4420 \
  centos@10.46.83.88
```

Verify: `curl -sk https://localhost:8443` should return the VAST login page.

## Step 3: Enable pod access to VAST (iptables)

Pods can't reach the tunnel endpoints directly. Add DNAT rules so pod traffic on NFS ports gets forwarded to the tunnel:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 2049 -j DNAT --to-destination <BEAKER_IP>:2049
sudo iptables -t nat -A PREROUTING -p tcp --dport 20048 -j DNAT --to-destination <BEAKER_IP>:20048
sudo iptables -t nat -A PREROUTING -p tcp --dport 4420 -j DNAT --to-destination <BEAKER_IP>:4420
sudo iptables -t nat -A PREROUTING -p tcp --dport 111 -j DNAT --to-destination <BEAKER_IP>:111
sudo iptables -t nat -A POSTROUTING -p tcp --dport 2049 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p tcp --dport 20048 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p tcp --dport 4420 -j MASQUERADE
```

## Step 4: Add VIP addresses for VAST CSI (optional — needed for NFS mounts)

The VAST CSI driver mounts NFS from VIP addresses (11.0.0.x). For the CSI to reach the tunnel, add VIPs as local addresses and start a second tunnel:

```bash
sudo ip addr add 11.0.0.2/32 dev lo
sudo ip addr add 11.0.0.3/32 dev lo

sudo ssh -i /root/.ssh/vast -o StrictHostKeyChecking=no -fN \
  -L 11.0.0.2:2049:11.0.0.2:2049 \
  -L 11.0.0.2:20048:11.0.0.2:20048 \
  -L 11.0.0.2:4420:11.0.0.2:4420 \
  -L 11.0.0.3:2049:11.0.0.3:2049 \
  -L 11.0.0.3:20048:11.0.0.3:20048 \
  -L 11.0.0.3:4420:11.0.0.3:4420 \
  centos@10.46.83.88
```

**Note:** NFS mounts through SSH tunnels have limitations — the VAST CSI can provision volumes (API calls work), but actual NFS mounts may fail due to source IP verification and NFS protocol constraints. This is sufficient for testing the OSAC storage controller lifecycle (Stage 1 + Stage 2 provisioning) but not for running VMs with VAST-backed storage.

## Step 5: Configure the OSAC operator

Create the `storage-operations-ig` Secret with VAST credentials:

```bash
oc create secret generic storage-operations-ig -n osac \
  --from-literal=VAST_ENDPOINT=https://<BEAKER_IP>:8443 \
  --from-literal=VAST_USERNAME=admin \
  --from-literal=VAST_PASSWORD=123456 \
  --from-literal=VAST_VALIDATE_CERTS=false \
  --from-literal=VAST_VIP_POOL_NAME=vippool-2 \
  --from-literal=VAST_VIP_POOL_SUBNET_CIDR=24 \
  --from-literal=VAST_VIP_POOL_GW_IP=11.0.0.1 \
  --from-literal='VAST_VIP_POOL_IP_RANGES=[["11.0.0.2","11.0.0.3"]]' \
  --from-literal='STORAGE_TIERS=[{"name":"default","protocol":"nfs","provider":"vast"}]' \
  --as system:admin
```

Set the storage config namespace (where hub Secrets are created):

```bash
oc set env deployment/osac-operator -n osac \
  OSAC_STORAGE_CONFIG_NAMESPACE=osac \
  --as system:admin
```

## Step 6: Verify

```bash
# Management API reachable from a pod
oc run vast-test --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --restart=Never --rm -i --timeout=30s --as system:admin -- \
  bash -c "curl -sk https://<BEAKER_IP>:8443 >/dev/null && echo OK || echo FAIL"

# Operator can reach AAP and trigger storage provisioning
oc get tenant -n osac -o wide
```

## Persistence

The SSH tunnel, iptables rules, and VIP addresses do NOT survive a reboot. To persist:

- **Tunnel:** Add the `ssh -fN ...` commands to a systemd unit or `/etc/rc.local`
- **iptables:** Save with `iptables-save > /etc/sysconfig/iptables` (RHEL) or use a systemd unit
- **VIPs:** Add to a NetworkManager connection or a systemd unit

For dev/test, re-running Steps 2-4 after reboot is usually easier.
