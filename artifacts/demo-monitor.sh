#!/bin/bash
# Demo monitor — run in a separate terminal during the org storage provisioning demo.
# Shows live status of the Tenant CR, provisioning jobs, and StorageClasses.
# Collects all data first, then renders in one shot to avoid screen flicker.
#
# Usage: bash artifacts/demo-monitor.sh [tenant-name] [namespace]

TENANT=${1:-demo-acme}
NS=${2:-osac-zszabo}
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
EL='\033[K'

render() {
    local buf=""
    buf+="${BOLD}═══ Org Storage Provisioning — Live Monitor ═══${NC}\n"
    buf+="${CYAN}Tenant:${NC} $TENANT\n\n"

    # Collect all data upfront
    local tenant_json sc_output timestamp
    tenant_json=$(oc get tenant.osac.openshift.io "$TENANT" -n "$NS" -o json --as system:admin 2>/dev/null)
    local tenant_exists=$?
    sc_output=$(oc get sc -l "osac.openshift.io/tenant=$TENANT" -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner,TIER:.metadata.labels.osac\.openshift\.io/storage-tier' --no-headers 2>/dev/null)
    timestamp=$(date +%H:%M:%S)

    if [ $tenant_exists -ne 0 ]; then
        buf+="${BOLD}Phase:${NC}        ${RED}deleted${NC}\n"
        buf+="\n${BOLD}StorageClasses (osac.openshift.io/tenant=$TENANT):${NC}\n"
        if [ -z "$sc_output" ]; then
            buf+="  (none)\n"
            buf+="\n${GREEN}Tenant deleted — cleanup complete.${NC}\n"
        else
            while IFS= read -r line; do
                buf+="  $line\n"
            done <<< "$sc_output"
            buf+="\n${YELLOW}Tenant deleted but StorageClasses remain — deprovisioning may still be running.${NC}\n"
        fi
        buf+="\n${CYAN}${timestamp}${NC} — refreshing every 3s (Ctrl+C to exit)\n"
        buf+="\033[J"
        buf="${buf//\\n/${EL}\\n}"
        tput cup 0 0
        echo -e "$buf"
        return
    fi

    # Parse all fields from the single JSON blob
    local parsed
    parsed=$(echo "$tenant_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
s = d.get('status', {})
m = d.get('metadata', {})

phase = s.get('phase', '')
sc_name = s.get('storageClass', '')
ns_name = s.get('namespace', '')
has_fin = 'yes' if 'osac.openshift.io/tenant' in m.get('finalizers', []) else 'no'
deleting = 'yes' if m.get('deletionTimestamp') else 'no'

# Conditions
cond_lines = []
for c in s.get('conditions', []):
    ok = c.get('status') == 'True'
    icon = '✓' if ok else '✗'
    color = '\033[0;32m' if ok else '\033[0;31m'
    msg = c.get('message', '')[:80]
    cond_lines.append(f'  {color}{icon}\033[0m {c[\"type\"]}: {c.get(\"reason\",\"\")} — {msg}')

# Jobs
job_lines = []
for j in s.get('jobs', []):
    state = j.get('state', '?')
    if state == 'Succeeded': color = '\033[0;32m'
    elif state == 'Failed': color = '\033[0;31m'
    elif state == 'Running': color = '\033[0;33m'
    else: color = '\033[0m'
    msg = j.get('message', '')[:50]
    job_lines.append(f'  {color}{j[\"type\"]:12s}  {state:10s}\033[0m  jobID={j.get(\"jobID\",\"\")}  {msg}')

print(f'PHASE={phase}')
print(f'SC_NAME={sc_name}')
print(f'NS_NAME={ns_name}')
print(f'HAS_FIN={has_fin}')
print(f'DELETING={deleting}')
print(f'COND_COUNT={len(cond_lines)}')
for l in cond_lines: print(f'COND={l}')
print(f'JOB_COUNT={len(job_lines)}')
for l in job_lines: print(f'JOB={l}')
" 2>/dev/null)

    local phase sc_name ns_name has_fin deleting
    phase=$(echo "$parsed" | grep '^PHASE=' | cut -d= -f2-)
    sc_name=$(echo "$parsed" | grep '^SC_NAME=' | cut -d= -f2-)
    ns_name=$(echo "$parsed" | grep '^NS_NAME=' | cut -d= -f2-)
    has_fin=$(echo "$parsed" | grep '^HAS_FIN=' | cut -d= -f2-)
    deleting=$(echo "$parsed" | grep '^DELETING=' | cut -d= -f2-)

    case "$phase" in
        Ready)       local pc="${GREEN}" ;;
        Progressing) local pc="${YELLOW}" ;;
        Failed|Deleting) local pc="${RED}" ;;
        *)           local pc="${NC}" ;;
    esac

    buf+="${BOLD}Phase:${NC}        ${pc}${phase:-unknown}${NC}\n"
    buf+="${BOLD}Namespace:${NC}    ${ns_name:--}\n"
    buf+="${BOLD}StorageClass:${NC} ${sc_name:--}\n"
    buf+="${BOLD}Finalizer:${NC}    ${has_fin}\n"
    [ "$deleting" = "yes" ] && buf+="${BOLD}Deleting:${NC}     ${RED}yes${NC}\n"

    buf+="\n${BOLD}Conditions:${NC}\n"
    local cond_count
    cond_count=$(echo "$parsed" | grep '^COND_COUNT=' | cut -d= -f2-)
    if [ "${cond_count:-0}" -eq 0 ]; then
        buf+="  (none)\n"
    else
        while IFS= read -r line; do
            buf+="${line#COND=}\n"
        done <<< "$(echo "$parsed" | grep '^COND=')"
    fi

    buf+="\n${BOLD}Jobs:${NC}\n"
    local job_count
    job_count=$(echo "$parsed" | grep '^JOB_COUNT=' | cut -d= -f2-)
    if [ "${job_count:-0}" -eq 0 ]; then
        buf+="  (none)\n"
    else
        while IFS= read -r line; do
            buf+="${line#JOB=}\n"
        done <<< "$(echo "$parsed" | grep '^JOB=')"
    fi

    buf+="\n${BOLD}StorageClasses (osac.openshift.io/tenant=$TENANT):${NC}\n"
    if [ -z "$sc_output" ]; then
        buf+="  (none)\n"
    else
        while IFS= read -r line; do
            buf+="  ${GREEN}${line}${NC}\n"
        done <<< "$sc_output"
    fi

    buf+="\n${CYAN}${timestamp}${NC} — refreshing every 3s\n"

    # Erase remnants: insert "clear to end of line" before every newline
    buf+="\033[J"
    buf="${buf//\\n/${EL}\\n}"

    tput cup 0 0
    echo -e "$buf"
}

clear
while true; do
    render
    sleep 3
done
