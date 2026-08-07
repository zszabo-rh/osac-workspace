# Focus Tracker

**Last session:** 2026-08-07 PM (OSAC-3234 E2E deep debug: MetalLB subnet fix, dual-NIC agent VM, RBAC for HostedControlPlane, Omer PR#198 reviewed, Roy PR#141 CI confirmed unrelated)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here), osac-project/osac-installer (archiving soon), osac-project/enhancement-proposals  
**Tracked PRs:** osac#141 (Roy OSAC-3271 CSI, BEHIND, zszabo APPROVED — needs Roy rebase; CodeRabbit CHANGES_REQUESTED is stale/false-alarm per review), osac#DRAFT (OSAC-3234 CaaS LVMS — branch `feat/OSAC-3234-caas-lvms` 4 commits ahead of main, draft PR to open after rebase+RBAC fix)
**Next action:** (1) Rebase feat/OSAC-3234-caas-lvms on upstream/main; (2) Fix RBAC for HostedControlPlane in operator ClusterRole (Helm chart); (3) Open draft PR; (4) Update edge-17 AAP project to use our branch and finish testing LVMS install path; (5) Reply to Akshay on OSAC-3404 → OSAC-3710/3711  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
