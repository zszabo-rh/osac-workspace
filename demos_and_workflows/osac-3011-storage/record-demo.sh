#!/bin/bash
#
# OSAC-3011 Demo Recording — Automatic Local Storage
#
# Two-phase setup (run BEFORE starting asciinema):
#   1. cluster-tool boot vmaas-4-22 osac-3011-demo
#   2. [WIP] Patch values/vmaas-ci/values.yaml with test images + ensure lvms.enabled: false
#   3. Run refresh-after-snapshot.py once (pods come up, no hook fires, API is ready)
#   4. Verify: oc get deployments -n osac-e2e-ci shows 1/1; API returns empty storage lists
#
# The script handles scene 2: it flips lvms.enabled to true and runs the second refresh.
# After recording, lvms.enabled is reset to false by the cleanup section.
#
# WIP values to patch (until PRs #397/#454/#474 merge):
#   operator.image.repository: quay.io/rh-ee-zszabo/osac-operator
#   operator.image.tag:        osac-3011-test
#   aap.configAsCode.projectGitUri:    https://github.com/zszabo-rh/osac-aap.git
#   aap.configAsCode.projectGitBranch: test/OSAC-3011-combined
#   lvms.enabled:              false   ← must be false before the pre-run refresh
#
# Usage (on edge-17, from /tmp/osac-installer):
#   export KUBECONFIG=/root/.kube/osac-3011-demo.kubeconfig
#   asciinema rec /tmp/osac-3011-demo.cast \
#     --command "bash /home/zszabo/projects/osac-workspace/demos_and_workflows/osac-3011-storage/record-demo.sh" \
#     --title "OSAC-3011: Automatic Local Storage"
#
set -euo pipefail

NAMESPACE="${NAMESPACE:-osac-e2e-ci}"
TENANT_NAME="${TENANT_NAME:-demo}"
VALUES_FILE="${VALUES_FILE:-values/vmaas-ci/values.yaml}"

BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'

ROUTE=""
TOKEN=""
NODE_IP=""

# ── Helpers ───────────────────────────────────────────────────────────────────

header() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}  $*${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  sleep 1
}

info() { echo ""; echo -e "  ${BLUE}ℹ${RESET}  $*"; }
ok()   { echo -e "  ${GREEN}✓${RESET}  $*"; }
note() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
pause() { sleep "${1:-1.5}"; }

type_cmd() {
  echo ""
  echo -ne "${GREEN}\$ ${RESET}"
  local cmd="$1"
  for (( i=0; i<${#cmd}; i++ )); do
    echo -n "${cmd:$i:1}"
    sleep 0.04
  done
  echo ""
  sleep 0.5
}

run() {
  type_cmd "$1"
  eval "$1"
  pause
}

refresh_auth() {
  ROUTE=$(oc get route -n "${NAMESPACE}" fulfillment-api -o jsonpath='{.spec.host}' 2>/dev/null || true)
  NODE_IP=$(oc get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  # Use Kubernetes service account token — trusted by the fulfillment gRPC server
  TOKEN=$(oc create token admin -n "${NAMESPACE}" 2>/dev/null || true)
}

# ── Scene 1: Clean state ──────────────────────────────────────────────────────

refresh_auth

header "Scene 1 / 5 — Starting state: OSAC running, local storage not yet registered"
pause 2

info "Cluster booted from vmaas-4-22 snapshot (OCP 4.22 SNO + LVMS pre-installed)"
run "oc get lvmcluster -A --no-headers"
pause

info "LVMS StorageClass is present — local disk is available"
run "oc get storageclass lvms-vg1 --no-headers"
pause

info "OSAC is running after initial refresh"
run "oc get deployments -n ${NAMESPACE} --no-headers | awk '{print \$1, \$2\"/\"\$3}' | column -t"
pause

info "Local storage registration is disabled (lvms.enabled: false)"
run "grep -A1 '^lvms:' ${VALUES_FILE}"
pause 2

info "The fulfillment API confirms — no StorageBackend registered:"
type_cmd "curl -sH 'Authorization: Bearer \$TOKEN' https://\${ROUTE}/api/private/v1/storage_backends"
curl -sk \
  --resolve "${ROUTE}:443:${NODE_IP}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://${ROUTE}/api/private/v1/storage_backends" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('  []' if not d.get('items') else d['items'])"
pause 1

info "No StorageTier registered either:"
type_cmd "curl -sH 'Authorization: Bearer \$TOKEN' https://\${ROUTE}/api/private/v1/storage_tiers"
curl -sk \
  --resolve "${ROUTE}:443:${NODE_IP}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://${ROUTE}/api/private/v1/storage_tiers" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('  []' if not d.get('items') else d['items'])"
pause 2

# ── Scene 2: Enable lvms + refresh ───────────────────────────────────────────

header "Scene 2 / 5 — Enable local storage and re-run refresh"
pause 1.5

note "(WIP) Values already patched with test operator image + fork AAP branch"
note "      After PRs #397/#454/#474 merge: plain refresh with unmodified values"
pause 1

info "Enable local storage registration — flip lvms.enabled to true:"
run "sed -i '/^lvms:/,/enabled/ s/: false/: true/' ${VALUES_FILE}"
run "grep -A1 '^lvms:' ${VALUES_FILE}"
pause 1

info "Re-run refresh — helm upgrade fires the register-local-storage hook:"
type_cmd "VALUES_FILE=${VALUES_FILE} INSTALLER_NAMESPACE=${NAMESPACE} python3 scripts/refresh-after-snapshot.py"
echo ""

VALUES_FILE="${VALUES_FILE}" \
  INSTALLER_NAMESPACE="${NAMESPACE}" \
  python3 scripts/refresh-after-snapshot.py

echo ""
ok "Refresh complete — hook fired, StorageBackend + StorageTier registered"
pause 2

# ── Scene 3: StorageBackend + StorageTier appeared ────────────────────────────

header "Scene 3 / 5 — StorageBackend and StorageTier auto-registered"
pause 1.5

# Let the ingress proxy fully initialize before making API calls
sleep 20

refresh_auth

info "The register-local-storage hook called the fulfillment API automatically"
pause 1

info "StorageBackend — the registered LVMS provider:"
type_cmd "curl -sH 'Authorization: Bearer \$TOKEN' https://\${ROUTE}/api/private/v1/storage_backends"
curl -sk \
  --resolve "${ROUTE}:443:${NODE_IP}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://${ROUTE}/api/private/v1/storage_backends" \
  | python3 -c "
import sys, json
for b in json.load(sys.stdin).get('items', []):
    m, sp, st = b['metadata'], b['spec'], b['status']
    print('  name:    ', m['name'])
    print('  provider:', sp['provider'])
    print('  state:   ', st['state'])
"
pause 2

info "StorageTier — the tenant-facing tier:"
type_cmd "curl -sH 'Authorization: Bearer \$TOKEN' https://\${ROUTE}/api/private/v1/storage_tiers"
curl -sk \
  --resolve "${ROUTE}:443:${NODE_IP}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://${ROUTE}/api/private/v1/storage_tiers" \
  | python3 -c "
import sys, json
for t in json.load(sys.stdin).get('items', []):
    m, st = t['metadata'], t['status']
    print('  name: ', m['name'])
    print('  state:', st['state'])
"
pause 2

ok "Both registered automatically — no manual steps"
pause 2

# ── Scene 4: Onboard a tenant ─────────────────────────────────────────────────

header "Scene 4 / 5 — Onboard tenant '${TENANT_NAME}'"
pause 1.5

info "No StorageClass for '${TENANT_NAME}' yet — tenant doesn't exist"
run "oc get storageclass -l osac.openshift.io/tenant=${TENANT_NAME} --no-headers 2>/dev/null || echo '  (none)'"
pause

info "Production path: osac create -f tenant.yaml"
info "  → fulfillment-service creates Keycloak org, networking defaults, distributes Tenant CR"
info "Dev path (used here): Tenant CR applied directly to the operator"
pause 2
type_cmd "oc new-project ${TENANT_NAME} && oc apply -n ${NAMESPACE} -f tenant-${TENANT_NAME}.yaml"
oc new-project "${TENANT_NAME}" 2>/dev/null || oc project "${TENANT_NAME}" 2>/dev/null || true
oc apply -n "${NAMESPACE}" -f - <<EOF
apiVersion: osac.openshift.io/v1alpha1
kind: Tenant
metadata:
  name: ${TENANT_NAME}
  namespace: ${NAMESPACE}
spec: {}
EOF
pause 2

info "Watching operator detect the tenant and trigger the AAP job..."
pause 1

until oc get tenant -n "${NAMESPACE}" "${TENANT_NAME}" \
      -o jsonpath='{.status.conditions}' 2>/dev/null \
    | python3 -c "
import sys, json
cs = json.load(sys.stdin)
if not cs:
    print('  (conditions not yet set)')
    exit(1)
for c in cs:
    mark = '\033[1;32m✓\033[0m' if c['status'] == 'True' else '○'
    print(f'  {mark}  {c[\"type\"]}: {c[\"reason\"]}')
all_true = all(c['status'] == 'True' for c in cs)
exit(0 if all_true else 1)
" 2>/dev/null; do
  sleep 5
  echo -ne "  ."
done
echo ""
ok "All conditions True"
pause 2

# ── Scene 5: StorageClass + PVC ───────────────────────────────────────────────

header "Scene 5 / 5 — StorageClass created, PVC works"
pause 1.5

info "StorageClass auto-created by AAP (local_lvms_storage role):"
run "oc get storageclass -l osac.openshift.io/tenant=${TENANT_NAME} --no-headers"
pause 2

info "Creating a PVC using the auto-provisioned StorageClass..."
cat > /tmp/demo-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${TENANT_NAME}-demo-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: osac-${TENANT_NAME}-local
  resources:
    requests:
      storage: 1Gi
EOF
run "oc apply -f /tmp/demo-pvc.yaml"

run "oc get pvc -n ${NAMESPACE} ${TENANT_NAME}-demo-pvc"
pause 1

info "Pending: correct — LVMS uses WaitForFirstConsumer"
info "Volume provisions on first workload schedule. StorageClass is functional."
pause 3

# ── Cleanup ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${DIM}# Cleaning up...${RESET}"
oc delete pvc -n "${NAMESPACE}" "${TENANT_NAME}-demo-pvc" --ignore-not-found 2>/dev/null || true
oc delete tenant -n "${NAMESPACE}" "${TENANT_NAME}" --ignore-not-found 2>/dev/null || true
oc delete namespace "${TENANT_NAME}" --ignore-not-found 2>/dev/null || true
# Reset lvms.enabled to false so the next pre-run starts from a clean state
sed -i '/^lvms:/,/enabled/ s/: true/: false/' "${VALUES_FILE}" 2>/dev/null || true
pause

# ── Wrap-up ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  Summary${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
ok "cluster-tool boot → refresh-after-snapshot.py → register-local-storage hook"
ok "  → StorageBackend + StorageTier registered automatically"
ok "New tenant onboarded → operator triggered AAP → StorageClass created"
ok "No manual storage configuration. No steps between install and use."
echo ""
info "PRs: osac-operator#397  osac-aap#454  osac-installer#474"
echo ""
sleep 3
