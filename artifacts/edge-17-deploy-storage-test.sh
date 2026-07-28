#!/usr/bin/env bash
# Deploy OSAC + mock VMS on edge-17 SNO for storage E2E testing.
# Run from osac-workspace/ with oc access to the cluster.
set -euo pipefail

NAMESPACE="${NAMESPACE:-osac}"
INSTALLER_DIR="${INSTALLER_DIR:-osac-installer}"

echo "=== Phase 1: Deploy OSAC via setup.sh ==="
cd "${INSTALLER_DIR}"
git submodule update --init --recursive

EXTRA_SERVICES=true \
INSTALLER_NAMESPACE="${NAMESPACE}" \
VALUES_FILE=values/vmaas-ci/values.yaml \
  ./scripts/setup.sh

cd ..

echo "=== Phase 2: Deploy mock VMS server ==="
# Create ConfigMap from actual mock server script
oc create configmap mock-vms-server \
  --from-file=mock_vms_server.py=osac-aap/tests/integration/mock_vms_server.py \
  -n "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

# Deploy mock VMS pod + service (skip the ConfigMap from the manifest, we just created it)
oc apply -f artifacts/mock-vms-deployment.yaml -n "${NAMESPACE}" -l 'app=mock-vms'
# Apply Pod and Service only (ConfigMap already created above with real content)
oc apply -f - -n "${NAMESPACE}" <<'PODEOF'
apiVersion: v1
kind: Pod
metadata:
  name: mock-vms
  labels:
    app: mock-vms
spec:
  initContainers:
  - name: generate-certs
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command:
    - sh
    - -c
    - |
      microdnf install -y openssl && \
      openssl req -x509 -newkey rsa:2048 \
        -keyout /certs/tls.key \
        -out /certs/tls.crt \
        -days 365 -nodes \
        -subj "/CN=mock-vms" \
        -addext "subjectAltName=DNS:mock-vms,DNS:mock-vms.osac.svc"
    volumeMounts:
    - name: certs
      mountPath: /certs
  containers:
  - name: mock-vms
    image: registry.access.redhat.com/ubi9/python-311:latest
    command:
    - sh
    - -c
    - |
      sed 's/127.0.0.1/0.0.0.0/' /app/mock_vms_server.py > /tmp/server.py
      python3 /tmp/server.py 18443 --tls --cert /certs/tls.crt --key /certs/tls.key
    ports:
    - containerPort: 18443
      name: https
    volumeMounts:
    - name: server-script
      mountPath: /app
    - name: certs
      mountPath: /certs
      readOnly: true
    readinessProbe:
      exec:
        command: ["python3", "-c", "import urllib.request,ssl;urllib.request.urlopen('https://localhost:18443/api',context=ssl._create_unverified_context())"]
      initialDelaySeconds: 2
      periodSeconds: 5
  volumes:
  - name: server-script
    configMap:
      name: mock-vms-server
  - name: certs
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mock-vms
spec:
  selector:
    app: mock-vms
  ports:
  - port: 18443
    targetPort: 18443
    name: https
PODEOF

echo "Waiting for mock VMS pod to be ready..."
oc wait pod/mock-vms -n "${NAMESPACE}" --for=condition=Ready --timeout=120s

echo "=== Phase 3: Enable storage controller ==="
# Create osac-config secret with storage controller env vars
oc create secret generic osac-config \
  --from-literal=OSAC_ENABLE_STORAGE_CONTROLLER=true \
  --from-literal=OSAC_STORAGE_CONFIG_NAMESPACE="${NAMESPACE}" \
  --from-literal=OSAC_STORAGE_BACKEND_AAP_PROVISION_TEMPLATE=osac-create-tenant-storage-backend \
  --from-literal=OSAC_STORAGE_BACKEND_AAP_DEPROVISION_TEMPLATE=osac-delete-tenant-storage-backend \
  --from-literal=OSAC_STORAGE_CLUSTER_AAP_PROVISION_TEMPLATE=osac-create-tenant-cluster-storage \
  --from-literal=OSAC_STORAGE_CLUSTER_AAP_DEPROVISION_TEMPLATE=osac-delete-tenant-cluster-storage \
  -n "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

# Restart operator to pick up the new config
oc rollout restart deployment/osac-operator-controller-manager -n "${NAMESPACE}"
oc rollout status deployment/osac-operator-controller-manager -n "${NAMESPACE}" --timeout=120s

echo "=== Phase 4: Configure AAP storage templates for mock VMS ==="
# The AAP config-as-code creates the job templates automatically.
# We need to configure the storage instance group to point at the mock VMS.
# This is done via a ConfigMap that the storage-operations-ig reads.
oc create configmap storage-operations-ig \
  --from-literal=VAST_ENDPOINT="mock-vms:18443" \
  --from-literal=VAST_USERNAME="admin" \
  --from-literal=VAST_PASSWORD="admin" \
  --from-literal=VAST_VIP_POOL_NAME="osac-test-pool" \
  --from-literal=VAST_VALIDATE_CERTS="false" \
  --from-literal=OSAC_STORAGE_CONFIG_NAMESPACE="${NAMESPACE}" \
  --from-literal=STORAGE_TIERS='[{"name":"default","protocol":"nfs","provider":"vast"}]' \
  -n "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

oc create secret generic storage-operations-ig \
  --from-literal=VAST_PASSWORD="admin" \
  -n "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

echo ""
echo "=== Deployment complete ==="
echo "Mock VMS:  https://mock-vms.${NAMESPACE}.svc:18443"
echo "Namespace: ${NAMESPACE}"
echo ""
echo "To run storage E2E tests:"
echo "  export OSAC_NAMESPACE=${NAMESPACE}"
echo "  export OSAC_STORAGE_CONFIG_NAMESPACE=${NAMESPACE}"
echo "  export OSAC_STORAGE_ENABLED=true"
echo "  cd osac-test-infra && make test-storage"
