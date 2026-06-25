#!/usr/bin/env bash
# Setup cluster-tool on edge-17 (RHEL 9) and boot a CI-equivalent OSAC cluster.
# Run as root on edge-17.
set -euo pipefail

echo "=== Step 1: Install prerequisites ==="
dnf install -y qemu-kvm libvirt virt-install python3 python3-pip git
systemctl enable --now libvirtd

echo "=== Step 2: Install cluster-tool ==="
pip3 install --user git+https://github.com/omer-vishlitzky/cluster-tool.git 2>&1 || {
    cd /tmp
    git clone https://github.com/omer-vishlitzky/cluster-tool.git
    cd cluster-tool
    pip3 install .
}

echo "=== Step 3: Pull CI flavor ==="
# Same flavor used by GitHub Actions E2E
python3 -m cluster_tool pull quay.io/rh-ee-ovishlit/cluster-flavors:vmaas-helm

echo "=== Step 4: Boot cluster ==="
python3 -m cluster_tool boot --flavor vmaas-helm --name storage-test

echo "=== Done! ==="
echo "Kubeconfig should be at: ~/.kube/storage-test.kubeconfig"
echo "Next: run OSAC deploy + storage config"
