#!/usr/bin/env bash
# Storage E2E CI config — run AFTER standard OSAC deployment + mock VMS.
# Creates the storage-operations-ig resources and associates them with
# AAP storage job templates.
#
# Prerequisites:
#   - OSAC deployed (Helm or setup.sh) with storage controller enabled
#   - Mock VMS pod + service running (see mock-vms-deployment.yaml)
#   - AAP controller operational with config-as-code bootstrap complete
set -euo pipefail

NAMESPACE="${NAMESPACE:-osac}"

# --- storage-operations-ig ConfigMap ---
# AAP storage instance group pods mount this as env vars.
oc apply -f - -n "${NAMESPACE}" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-operations-ig
data:
  STORAGE_TIERS: '[{"name": "default", "protocol": "nfs", "provider": "vast"}]'
  STORAGE_PROVISIONING_TARGET: "vmaas"
  VAST_VALIDATE_CERTS: "false"
  VAST_VIP_POOL_NAME: "osac-test-pool"
  VAST_VIP_POOL_IP_RANGES: "10.0.0.100-10.0.0.200"
  VAST_VIP_POOL_SUBNET_CIDR: "10.0.0.0/24"
  OSAC_STORAGE_CONFIG_NAMESPACE: osac
EOF

# --- storage-operations-ig Secret ---
# VAST admin credentials for the mock VMS server.
oc apply -f - -n "${NAMESPACE}" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: storage-operations-ig
type: Opaque
stringData:
  VAST_ENDPOINT: "https://mock-vms:18443"
  VAST_USERNAME: "admin"
  VAST_PASSWORD: "mock"
EOF

# --- Associate instance group with storage job templates ---
# The config-as-code bootstrap creates the templates but doesn't
# associate the storage-operations-ig instance group automatically.
AAP_ROUTE=$(oc get route osac-aap-controller -n "${NAMESPACE}" -o jsonpath='{.spec.host}')
AAP_TOKEN=$(oc get secret osac-aap-admin-password -n "${NAMESPACE}" -o jsonpath='{.data.password}' | base64 -d)

# Find instance group ID
IG_ID=$(curl -sk "https://${AAP_ROUTE}/api/controller/v2/instance_groups/?name=osac-storage-operations-ig" \
  -H "Authorization: Bearer ${AAP_TOKEN}" | python3 -c "import sys,json; print(json.load(sys.stdin)['results'][0]['id'])")

# Find and associate all 4 storage job templates
for template in osac-create-tenant-storage-backend osac-delete-tenant-storage-backend \
                osac-create-tenant-cluster-storage osac-delete-tenant-cluster-storage; do
  JT_ID=$(curl -sk "https://${AAP_ROUTE}/api/controller/v2/job_templates/?name=${template}" \
    -H "Authorization: Bearer ${AAP_TOKEN}" | python3 -c "import sys,json; r=json.load(sys.stdin)['results']; print(r[0]['id']) if r else exit(1)") || continue
  curl -sk -X POST "https://${AAP_ROUTE}/api/controller/v2/job_templates/${JT_ID}/instance_groups/" \
    -H "Authorization: Bearer ${AAP_TOKEN}" -H "Content-Type: application/json" \
    -d "{\"id\": ${IG_ID}}" >/dev/null
  echo "Associated ${template} (${JT_ID}) with storage-operations-ig (${IG_ID})"
done

echo "Storage E2E config complete."
