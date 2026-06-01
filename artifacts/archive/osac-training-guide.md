# OSAC Training and Onboarding Guide

Welcome to the Open Sovereign AI Cloud (OSAC) project. This guide is designed to take you from zero context to a working understanding of the platform, its ecosystem, and its architecture. It is not a quickstart or a reference card -- it is a training document that explains not just *what* things are, but *why* they are that way.

If you are looking for command-by-command developer reference material, see `CLAUDE.md` in the project root. This guide is complementary: it gives you the mental model you need to make sense of those commands.

---

## Table of Contents

1. [What is OSAC and Why Does It Exist?](#1-what-is-osac-and-why-does-it-exist)
2. [The MOC Ecosystem (Critical Context)](#2-the-moc-ecosystem-critical-context)
3. [ESI (Elastic Secure Infrastructure)](#3-esi-elastic-secure-infrastructure)
4. [OSAC Architecture (Deep Dive)](#4-osac-architecture-deep-dive)
5. [Resource Types and How They're Provisioned](#5-resource-types-and-how-theyre-provisioned)
6. [The Provisioning Flow (Step by Step)](#6-the-provisioning-flow-step-by-step)
7. [ColdFront and Resource Allocation](#7-coldfront-and-resource-allocation)
8. [Multi-Tenancy Model](#8-multi-tenancy-model)
9. [Authentication and Access Control](#9-authentication-and-access-control)
10. [Quota Management (Proposed Feature)](#10-quota-management-proposed-feature)
11. [Development Environment](#11-development-environment)
12. [Repository Map](#12-repository-map)
13. [Key Technologies Reference](#13-key-technologies-reference)
14. [Common Tasks and Troubleshooting](#14-common-tasks-and-troubleshooting)

---

## 1. What is OSAC and Why Does It Exist?

**OSAC** stands for **Open Sovereign AI Cloud**. It is an open-source platform that allows organizations to deploy their own self-service cloud infrastructure, with a particular focus on AI workloads that need GPUs, bare metal performance, and strong tenant isolation.

### What "Sovereign" Means

The word "sovereign" is the key. It means organizations control their own infrastructure without depending on commercial cloud providers like AWS, Azure, or GCP. A university, a national lab, or a government agency can run OSAC on their own hardware and offer cloud-like self-service to their users -- without sending data or workloads to someone else's datacenter.

This matters for:
- **Data sovereignty:** Research data stays in your jurisdiction, on your hardware
- **Cost control:** No commercial cloud markup on GPU hours
- **Compliance:** You control the physical location, access policies, and audit trail
- **AI workload requirements:** High-performance networking (RoCE), GPU direct access, and bare metal performance that commercial clouds either don't offer or charge a premium for

### What OSAC Actually Provides

OSAC provides multi-tenant self-service for three types of infrastructure:

| Service | What You Get | Status |
|---------|-------------|--------|
| **Cluster-as-a-Service (CaaS)** | Full OpenShift clusters on bare metal | Production |
| **VM-as-a-Service (VMaaS)** | Virtual machines via OCP-Virt/KubeVirt | Production |
| **Bare Metal-as-a-Service** | Direct access to physical servers | Planned |

A tenant (a research group, a department, a company) can log in, pick a template, and get a fully provisioned cluster or VM in minutes -- without filing a ticket, without waiting for an admin.

### Origin Story

OSAC is a **Red Hat Research** collaboration with the **Massachusetts Open Cloud (MOC)**, a multi-university partnership hosted at the Massachusetts Green High Performance Computing Center (MGHPCC) in Holyoke, Massachusetts. The MOC has been operating since 2014, and OSAC emerged from its need for a modern, automated, multi-tenant platform that could serve multiple universities simultaneously.

The project was originally called "AI-in-a-Box" and later "innabox" (you will see these names in code, namespaces, and URLs -- they are the same project). It was also known as **"cloudkit"** -- this name persists widely in the codebase: CRDs use the `cloudkit.openshift.io` API group, template IDs follow the pattern `cloudkit.templates.ocp_4_17_small`, and provisioning playbooks are named `playbook_cloudkit_create_hosted_cluster.yml`. It was renamed to OSAC as it grew beyond its initial MOC-specific scope. You will encounter all three names (innabox, cloudkit, OSAC) interchangeably in code, configs, and discussions.

> **Common Misconception:** OSAC is NOT a product you install and it replaces your entire cloud. It is a layer that sits on top of existing infrastructure (OpenShift, RHACM, OpenStack/ESI, AAP) and provides the multi-tenant self-service experience on top of them.

---

## 2. The MOC Ecosystem (Critical Context)

To understand OSAC, you must first understand the environment it was born in. Many architectural decisions make no sense without this context.

### The MOC Alliance

The **Mass Open Cloud (MOC) Alliance** is a partnership of:
- **Boston University (BU)**
- **Harvard University**
- **Massachusetts Institute of Technology (MIT)**
- **Northeastern University**
- **University of Massachusetts**

All hosted at **MGHPCC (Massachusetts Green High Performance Computing Center)**, a shared datacenter in Holyoke, MA. MGHPCC provides the physical facility, power, cooling, and network connectivity. The MOC Alliance operates cloud services on top of that infrastructure.

### MOC is NOT Just OSAC

This is one of the most important things to internalize early. The MOC has been running cloud services since 2014. OSAC is the *newest* addition to a multi-service ecosystem. When you join the project, you will encounter references to these other services constantly.

The MOC provides:

| Service | Technology | What It Does | Who Uses It |
|---------|-----------|--------------|-------------|
| **OpenStack** | Nova, Neutron, Ironic, Keystone, Glance | Traditional IaaS: VMs, networks, bare metal | Researchers who want a VM |
| **OpenShift** | OCP clusters managed by NERC | Container platform | Teams running containerized workloads |
| **SLURM** | SLURM batch scheduler | HPC batch job scheduling | Traditional HPC users (ML training, simulations) |
| **ESI** | OpenStack Ironic with multi-tenancy | Bare metal leasing with L2 isolation | Teams needing raw hardware |
| **OSAC** | This project | Cluster/VM-as-a-Service with full automation | Teams needing full managed clusters |

OSAC is one of several access paths to the shared compute pool -- not the single entrypoint that replaces everything else.

### The Full Picture

Here is how all these services relate to the physical infrastructure:

```
MGHPCC Datacenter
+------------------------------------------------------------------+
|                                                                  |
|  +---------------------+    +---------------------+             |
|  |  OpenStack Control   |    |  OSAC Hub Cluster    |            |
|  |  Plane               |    |  (e.g. hypershift1)  |            |
|  |                      |    |                      |            |
|  |  Nova (VMs)          |    |  RHACM + HCP         |            |
|  |  Neutron (network)   |    |  OSAC Operator       |            |
|  |  Ironic (bare metal  |    |  Fulfillment Service |            |
|  |    -- this IS ESI)   |    |  AAP                 |            |
|  |  Keystone (auth)     |    |  KubeVirt            |            |
|  |  Glance (images)     |    |  Keycloak            |            |
|  |                      |    |  Tenant ctrl planes  |            |
|  +----------+-----------+    |  Tenant VMs          |            |
|             |                +----------+-----------+            |
|             |     ESI APIs              |  ESI Ansible           |
|             <---------------------------+  collection            |
|             |                                                    |
|  +----------v--------------------------------------------+       |
|  |              Bare Metal Host Pool                      |      |
|  |  [fc430] [fc430] [fc430] [A100] [A100] [H100] [H100]  |      |
|  |  Managed by Ironic/ESI                                 |      |
|  |  Leased to tenants as cluster workers, OpenStack BM,   |      |
|  |  etc.                                                   |      |
|  +--------------------------------------------------------+      |
|                                                                  |
|  +------------------+    +------------------+                    |
|  |  ColdFront        |    |  SLURM cluster    |                  |
|  |  (web app)         |    |  (batch HPC)      |                  |
|  +------------------+    +------------------+                    |
+------------------------------------------------------------------+
```

> **Key Insight:** The bare metal host pool at the bottom is a *shared* physical resource. The same physical servers can be leased through ESI to OpenStack, to OSAC for cluster worker nodes, or directly to tenants. They are not dedicated to any one service. This is why ESI's multi-tenancy and OSAC's quota management are so important -- they govern who gets access to this shared pool.

### Why This Matters for OSAC Development

When you work on OSAC, you are not building a standalone product. You are building one layer of a multi-layer cake. You will need to:

1. Understand that users may come to OSAC *after* already using OpenStack or SLURM -- they have expectations
2. Know that ColdFront manages quotas across *all* these platforms, not just OSAC
3. Accept that ESI/Ironic is the bare metal management layer -- OSAC does not talk to hardware directly
4. Recognize that changes to OSAC's network isolation must be compatible with the broader MOC networking

---

## 3. ESI (Elastic Secure Infrastructure)

ESI is one of the most important pieces of context for OSAC, and also one of the most commonly misunderstood.

### What ESI Actually Is

**ESI is NOT a separate piece of software.** ESI is OpenStack Ironic with multi-tenancy extensions. Specifically, it adds `owner` and `lessee` fields to Ironic's node objects, which enables fine-grained access control over who can use which physical servers.

If you have used OpenStack before:
- **Ironic** = OpenStack's bare metal provisioning service (think "Nova, but for physical machines instead of VMs")
- **ESI** = Ironic configured for multi-tenant bare metal leasing, with additional access control

The name "Elastic Secure Infrastructure" describes the concept, not a separate codebase.

### The Problem ESI Solves

Traditional bare metal provisioning gives a single administrator control over all machines. That doesn't work when multiple organizations (universities, research groups) need to share a pool of physical servers:

- **Without ESI:** One admin manages all servers. Tenants submit tickets. No self-service.
- **With ESI:** Each organization can see and manage only their leased servers. Self-service provisioning. Automatic L2 network isolation.

### How ESI Works

```
Physical Servers in Datacenter
+-----------------------------------------------------+
|  Server A (fc430)    Server B (A100)    Server C     |
|  owner: university1  owner: university2  owner: none |
|  lessee: project-x   lessee: none        lessee: none|
+-----------------------------------------------------+
           |                    |                |
           v                    v                v
+-----------------------------------------------------+
|                    Ironic / ESI                       |
|  - Tracks all servers with BMC credentials            |
|  - Enforces owner/lessee access control               |
|  - Provisions OS via PXE boot                         |
|  - Manages L2 network attachments via Neutron         |
+-----------------------------------------------------+
           |
           v
+-----------------------------------------------------+
|  Ironic REST API (= ESI API)                          |
|  - List nodes (filtered by your tenant)               |
|  - Lease a node                                       |
|  - Power on/off                                       |
|  - Attach to network                                  |
|  - Set boot device                                    |
+-----------------------------------------------------+
```

### How OSAC Uses ESI

OSAC does not talk to physical servers directly. When OSAC needs bare metal machines for cluster worker nodes, the provisioning flow goes:

1. OSAC Operator reconciles a ClusterOrder or HostPool
2. OSAC triggers an Ansible playbook via AAP
3. The playbook uses the **ESI Ansible collection** (`massopencloud.esi`)
4. The ESI collection calls Ironic's REST API to lease nodes, attach networks, and boot machines
5. The machines join the cluster as worker nodes

The ESI Ansible collection lives at: `osac-aap/collections/ansible_collections/massopencloud/esi/`

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| **Resource class** | Hardware type identifier (e.g., `fc430`, `A100`, `H100`). Maps to Ironic resource classes. |
| **Owner** | The organization that permanently owns a set of machines |
| **Lessee** | The tenant currently leasing machines from an owner |
| **Elastic leasing** | When machines are idle, they can be leased to other tenants. When the owner needs them back, leases are revoked. |
| **L2 isolation** | Each tenant's machines are placed on their own Layer 2 network, preventing cross-tenant traffic at the switch level |

> **Common Misconception:** "ESI is a separate service that OSAC depends on." No -- ESI is how Ironic is deployed at MOC. If you deployed OSAC at a different datacenter without OpenStack, you would need a different bare metal management layer. The ESI Ansible collection is the integration point and could be swapped for a different collection targeting a different bare metal management API.

---

## 4. OSAC Architecture (Deep Dive)

Now that you understand the ecosystem, let's look at OSAC's internal architecture.

### The Three Major Components

OSAC has three major components that work together in a pipeline:

```
+-----------------------------------------------------------------------------+
|                              USER INTERFACES                                 |
|     +--------------+    +--------------+    +--------------+                |
|     |   OSAC UI    |    |Fulfillment   |    |  Custom UIs  |                |
|     |  (Web App)   |    |    CLI       |    |  (CSP Built) |                |
|     +------+-------+    +------+-------+    +------+-------+                |
+------------|--------------------|--------------------|-----------------------+
             |                    |                    |
             v                    v                    v
+-----------------------------------------------------------------------------+
|                         FULFILLMENT SERVICE                                  |
|     +-------------------------------------------------------------+         |
|     |  REST/gRPC API  |  PostgreSQL  |  Hub Scheduler  |  Auth    |         |
|     +-------------------------------------------------------------+         |
+-----------------------------------------------------------------------------+
                                   |
                                   |  Creates ClusterOrder/ComputeInstance CRs
                                   v
+-----------------------------------------------------------------------------+
|                      MANAGEMENT CLUSTER (Hub)                                |
|     +-------------------+    +-------------------+    +------------------+  |
|     |   OSAC Operator   |--->|  AAP Provider     |--->|  AAP Controller  |  |
|     |  (K8s Controller) |    |  (EDA/Direct)     |    |  (Job Templates) |  |
|     +-------------------+    +-------------------+    +------------------+  |
|     +-------------------------------------------------------------------+   |
|     |  RHACM (HCP)  |  OpenShift Virtualization  |  Networking  | Storage | |
|     +-------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------+
```

#### 1. Fulfillment Service (Go/gRPC)

This is the front door. It receives all provisioning requests, whether they come from the CLI, the web UI, or a custom integration.

What it does:
- **Receives requests** via gRPC and REST APIs
- **Validates** request parameters against template schemas
- **Schedules** requests to Management Clusters (Hubs) -- currently random selection, future: capacity-aware
- **Creates Custom Resources** (ClusterOrder, ComputeInstance) on the selected Hub
- **Stores state** in PostgreSQL with a JSONB-based polymorphic schema
- **Tracks status** by watching the CRs on Hubs and syncing status back to its database

The Fulfillment Service exists as a separate layer (rather than exposing the Kubernetes API directly) for critical reasons:
- **Privilege separation:** The API server that faces the internet cannot directly modify infrastructure
- **Multi-tenancy:** Kubernetes namespace-based RBAC is insufficient for cloud-grade tenant isolation
- **Topology awareness:** Multiple Hubs can exist; the Fulfillment Service handles scheduling across them
- **API safety:** The raw Kubernetes API exposes too much control surface for untrusted users

> **Key Insight:** The Fulfillment Service's PostgreSQL schema uses JSONB columns for resource-type-specific data. This means cluster data, VM data, and bare metal data all live in the same `resources` table, with type-specific details stored as JSON. Multi-tenancy is enforced at the database level with a `tenants[]` array column and GIN indexes, so every query is automatically scoped to the requesting tenant's resources.

##### Hub Registration and Multi-Hub Architecture

The Fulfillment Service is a **single central instance** -- it is NOT deployed per-hub. It maintains a **registry of hubs** via a private gRPC API (cluster-internal only, not exposed to tenants). Each hub is registered with a kubeconfig and namespace:

```bash
fulfillment-cli create hub --kubeconfig=kubeconfig.hub-access --id my-hub --namespace osac
```

Each hub runs its own OSAC Operator + AAP stack independently. The Fulfillment Service connects to multiple hubs via their stored kubeconfigs, using **HubCache** for lazy-loaded cached Kubernetes client connections per hub.

Key multi-hub behaviors:
- **Hub selection is currently random** among available hubs -- there is no load balancing or capacity awareness
- Once a resource is assigned to a hub, it stays there permanently (immutable assignment via `status.hub` field)
- **Tenants are hub-unaware** -- they cannot choose or see which hub their resources run on
- A single tenant can have resources scattered across multiple hubs
- In single-hub deployments (like the current MOC setup on hypershift1), this multi-hub complexity is invisible

Upon registration, the service **automatically syncs all available compute and cluster templates** from that hub. This is an important detail: template discovery happens at hub registration time, not at request time. If new templates are added later, the hub must be re-synced or the discovery process re-triggered.

##### Public vs. Private API

The Fulfillment Service exposes two API surfaces:

| API | Location | Access | Purpose |
|-----|----------|--------|---------|
| **Public API** | `fulfillment-api/` repo | Exposed via Route/Ingress, used by CLI/UI/tenants | Resource provisioning, template listing, status queries |
| **Private API** | `fulfillment-service/` repo | Cluster-internal only | Hub management, internal operations, template sync |

The split is a deliberate **code organization and stability contract** choice -- it is NOT about gRPC RBAC limitations. gRPC fully supports per-method RBAC. The separation ensures the public API surface remains stable for external consumers while the private API can evolve freely for internal operations.

##### Template Discovery and Data Flow

Templates are discovered via an AAP discovery job that scans Ansible collections for `meta/cloudkit.yaml` metadata. The data flow is:

```
AAP discovery job --> publishes via Fulfillment Service API --> PostgreSQL (cluster_templates table)
```

Status feedback follows the reverse path:

```
Fulfillment Service creates CRs on hub --> Operator updates CR status -->
Fulfillment Service reconciler reads CR status back --> updates PostgreSQL
```

The reconciler operates in two modes: **event-driven** (PostgreSQL `NOTIFY`/`LISTEN` triggers immediate reconciliation when records change) and **periodic sync** (hourly full reconciliation to ensure no updates are missed).

#### 2. OSAC Operator (Kubebuilder/Go)

This is the brains on the Management Cluster. It watches for Custom Resources created by the Fulfillment Service and reconciles them -- meaning it takes action to make reality match the desired state.

What it does:
- **Watches** for ClusterOrder, ComputeInstance, HostPool, and Tenant CRs
- **Creates infrastructure prerequisites:** namespaces, service accounts, RBAC
- **Triggers AAP automation** via webhooks (EDA) or REST API (AAP Direct)
- **Monitors status** of HostedClusters, VMs, and other resources
- **Updates CR status** so the Fulfillment Service can pick up changes
- **Handles deletion** with finalizers to ensure clean teardown

The operator follows the standard Kubernetes controller pattern: watch for changes, reconcile to desired state, repeat.

#### 3. Ansible Automation Platform (AAP)

This is the hands. AAP executes the actual provisioning work through Ansible playbooks and roles.

What it does:
- **Receives events** from the operator (via EDA webhooks or direct REST API calls)
- **Runs Ansible playbooks** that create HostedClusters, NodePools, VMs, network configurations
- **Executes templates** -- the Ansible roles that define how infrastructure gets provisioned
- **Interacts with ESI** via the `massopencloud.esi` Ansible collection for bare metal operations

There are two integration models for how the operator talks to AAP:

| Model | How It Works | Pros | Cons |
|-------|-------------|------|------|
| **EDA (Legacy)** | Fire-and-forget webhooks to Event-Driven Ansible | Simple setup | No job tracking, no cancellation, playbook manages finalizers |
| **AAP Direct (Recommended)** | REST API calls with job ID tracking | Job status polling, cancellation, crash recovery, operator manages finalizers | More configuration |

### Custom Resource Definitions (CRDs)

OSAC defines four CRDs under the **`osac.openshift.io/v1alpha1`** API group. (Note: some older code still references the previous name `cloudkit.openshift.io` -- these are the same CRDs.) All are namespaced resources.

| CRD | Short Name | Purpose | Created By | Reconciled By |
|-----|-----------|---------|-----------|---------------|
| `ClusterOrder` | `cord` | Cluster provisioning lifecycle (spec has `templateID`, `templateParameters`, `nodeRequests[]`; status has `phase`, `conditions[]`, `clusterReference`) | Fulfillment Service | OSAC Operator |
| `ComputeInstance` | `ci` | VM provisioning lifecycle (spec has `templateID`, `cores`, `memoryGiB`, `bootDisk`, `image` -- most fields immutable; status has `phase`, `virtualMachineReference`, `jobs[]`) | Fulfillment Service | OSAC Operator |
| `HostPool` | `hp` | Manage a pool of physical bare metal hosts (spec has `hostSets[]`) | Fulfillment Service | OSAC Operator |
| `Tenant` | -- | Represent a tenant organization -- creates namespace + OVN `UserDefinedNetwork` for L2 network isolation | Admin/Fulfillment Service | OSAC Operator |

These CRDs live in `osac-operator/api/v1alpha1/`.

Key annotation: `osac.openshift.io/management-state: manual|unmanaged` controls whether the operator actively reconciles a resource or leaves it alone.

### What Runs on Hub Worker Nodes

This is something that trips up newcomers: the Hub cluster's worker nodes are *heavily loaded*. They host:

1. **Tenant cluster control planes** -- HyperShift pods (API server, etcd, controller-manager, scheduler for each tenant cluster)
2. **Tenant VMs** -- OCP-Virt/KubeVirt virtual machines
3. **OSAC infrastructure itself** -- Fulfillment Service, operator, AAP, Keycloak, PostgreSQL, Authorino

This means Hub worker nodes need to be beefy machines with plenty of CPU, memory, and fast storage (etcd for each hosted control plane needs low-latency disk I/O).

> **Key Insight:** When a tenant requests a cluster, the *control plane* runs as lightweight pods on the Hub. Only the *worker nodes* consume separate (usually bare metal) machines from the ESI pool. This is the HyperShift model: it dramatically reduces per-cluster overhead because you don't need 3 dedicated machines just for the control plane.

---

## 5. Resource Types and How They're Provisioned

### Clusters (HyperShift / Hosted Control Planes)

When a tenant requests a cluster, they get an OpenShift cluster where:

- **Control plane** runs as pods on the Hub cluster (no dedicated machines needed)
- **Worker nodes** come from the ESI bare metal pool (physical servers)

```
Hub Cluster
+----------------------------------------------------+
|  Hub Worker Node 1        Hub Worker Node 2         |
|  +-----------------+      +-----------------+       |
|  | Tenant-A etcd   |      | Tenant-B etcd   |      |
|  | Tenant-A API    |      | Tenant-B API    |      |
|  | Tenant-A ctrl   |      | Tenant-B ctrl   |      |
|  +-----------------+      +-----------------+       |
|  | OSAC Operator   |      | Fulfillment Svc |       |
|  | AAP             |      | PostgreSQL      |       |
|  +-----------------+      +-----------------+       |
+----------------------------------------------------+

Bare Metal Pool (ESI)
+----------------------------------------------------+
|  [fc430] -----+    [A100] -----+    [H100]          |
|  [fc430] -----+--- Tenant-A   |--- Tenant-B         |
|  [fc430] -----+    Workers    |    Workers           |
|               |               |                      |
|     L2 network A    L2 network B                     |
+----------------------------------------------------+
```

The benefits of this model:
- **Fast provisioning:** No need to boot 3 control plane machines -- pods start in seconds
- **Higher density:** One Hub can host dozens of tenant control planes
- **Cost efficiency:** Control planes share Hub infrastructure instead of each needing dedicated hardware
- **Easier upgrades:** Control plane upgrades are pod rolling updates, not machine-level operations

### VMs (OCP-Virt / KubeVirt)

When a tenant requests a VM, it runs directly on the Hub cluster's worker nodes using KubeVirt (OpenShift Virtualization):

- The VM runs as a `VirtualMachineInstance` pod on a Hub worker node
- VM disk images come from pre-loaded templates (RHEL 7-10, Fedora, CentOS, Windows)
- Live migration between Hub workers is supported (using NFS `nfs-vm-dynamic` storage class)

VMs share the Hub worker nodes with HyperShift control planes and OSAC infrastructure. This is fine for lightweight VMs but means very large or GPU-passthrough VMs compete with control plane workloads for Hub resources.

### Bare Metal Hosts (Planned)

Direct bare metal leasing will allow tenants to get raw physical servers from the ESI pool without wrapping them in a cluster or VM. The `HostPool` CRD already exists to manage groups of bare metal machines.

### The Template System

All resource provisioning in OSAC is template-driven. Templates are **Ansible roles** that encode the complete provisioning logic for a specific configuration.

```
roles/ocp_4_17_small/
+-- tasks/
|   +-- install.yaml       # Create HostedCluster, NodePools, networking
|   +-- postinstall.yaml   # Configure OAuth, install operators, etc.
|   +-- delete.yaml        # Tear down everything
+-- defaults/
|   +-- main.yaml          # Default parameter values
+-- meta/
    +-- cloudkit.yaml      # OSAC metadata (title, description, type)
    +-- argument_specs.yaml # Parameter definitions and validation
```

The `meta/cloudkit.yaml` file tells OSAC what kind of resource this template creates:

```yaml
title: "OpenShift 4.17 small"
description: "OpenShift 4.17 with small instances as worker nodes"
template_type: cluster    # or 'vm'
default_node_request:
  - resourceClass: fc430
    numberOfNodes: 2
```

Cloud Service Providers (CSPs) can create custom templates to offer different cluster configurations -- pre-installed monitoring, specific security policies, GPU-optimized setups, etc. Organizations can create their own Ansible collections with custom templates; with appropriate AAP configuration, the template discovery job will find these new templates automatically.

### Template Discovery

Templates are not statically configured -- they are **discovered** via an AAP job. When the system bootstraps (or when a hub is registered), an AAP discovery job runs that:

1. Scans available Ansible collections for roles with OSAC metadata (`meta/cloudkit.yaml`)
2. **Extracts metadata** from each template: description, supported parameters, resource class requirements
3. **Publishes** that information to the fulfillment service, making templates available via the API

The `argument_specs.yaml` file in each template serves a dual purpose: it provides **runtime argument validation** (Ansible uses it to enforce required parameters and types when the role executes) AND it provides **metadata about available parameters** (name, description, validation constraints) that gets published during discovery so the CLI and UI can display parameter information to users.

Currently available templates:

| Template | Type | Description |
|----------|------|-------------|
| `ocp_4_17_small` | Cluster | Minimal OpenShift 4.17 cluster |
| `ocp_4_17_small_github` | Cluster | OpenShift 4.17 with GitHub OAuth |
| `ocp_virt_vm` | VM | Configurable virtual machine |

> **Key Insight:** Template resolution happens *implicitly* inside Ansible at provisioning time. There is currently no queryable API for "given this template and these parameters, what resources will actually be consumed?" This is a known architectural gap that matters for quota management, billing, capacity planning, and UI previews. See the Quota Management section for more on this.

---

## 6. The Provisioning Flow (Step by Step)

Let's trace a complete cluster provisioning request from user action to running cluster.

### Resource Lifecycle Model (Important)

There is **NO separate "request" entity** in OSAC. The resource record (a row in the `clusters`, `compute_instances`, or `host_pools` table) IS the request. The same row progresses through the entire lifecycle:

```
Without quotas:  creation → progressing → ready → deleted     (all same DB row)
With quotas:     creation → pending → approved → progressing → ready → deleted  (all same DB row)
```

With the quota feature, the Kubernetes CR (ClusterOrder, ComputeInstance, HostPool) is **only created on the hub AFTER approval**. During the "pending" state, the resource exists only in the Fulfillment Service PostgreSQL database -- there is no Kubernetes representation on any hub cluster. The CR creation itself is the provisioning trigger.

### Step 1: User Submits Request

```bash
fulfillment-cli create cluster \
  --template ocp_4_17_small \
  --name my-cluster \
  -p pull_secret="$(cat pull-secret.json)" \
  -p ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
```

The CLI sends a gRPC `Create` request to the Fulfillment Service with the template ID, cluster name, and parameters.

### Step 2: Fulfillment Service Validates and Schedules

The Fulfillment Service:
1. **Authenticates** the request (OAuth2/OIDC via Keycloak)
2. **Identifies the tenant** from the auth token
3. **Validates** the template exists and parameters are correct
4. **Selects a Hub** (currently random selection from registered Hubs)
5. **Creates a record** in PostgreSQL with status `PROGRESSING`
6. **Creates a `ClusterOrder` CR** on the selected Hub via the Kubernetes API

```yaml
apiVersion: osac.redhat.com/v1alpha1
kind: ClusterOrder
metadata:
  name: my-cluster-abc123
  namespace: tenant-namespace
spec:
  templateID: ocp_4_17_small
  templateParameters: |
    {"pull_secret": "...", "ssh_public_key": "..."}
  nodeRequests:
    - resourceClass: fc430
      numberOfNodes: 2
```

### Step 3: OSAC Operator Reconciles

The OSAC Operator on the Hub detects the new ClusterOrder and:

1. **Sets status** to `Progressing`
2. **Creates namespace** for the cluster (named after the cluster ID)
3. **Creates ServiceAccount** and **RoleBindings** for cluster automation
4. **Triggers AAP** -- either fires an EDA webhook or calls the AAP REST API with the ClusterOrder spec

### Step 4: AAP Executes the Template

AAP receives the event and runs the playbook `playbook_cloudkit_create_hosted_cluster.yml`, which:

1. **Acquires a cluster lock** to prevent concurrent operations on the same cluster
2. **Adds a finalizer** to the ClusterOrder (so deletion waits for cleanup)
3. **Includes the template role** (`ocp_4_17_small`) and runs its `install.yaml` tasks
4. **Creates a `HostedCluster` resource** (HyperShift) with the specified configuration
5. **Creates `NodePool` resources** that reference the bare metal machines
6. **Selects and labels bare metal agents** -- bare metal resources are exposed to OpenShift as **agents**. When a node is imported, it is labeled with ESI metadata: node UUID, resource class (e.g., `fc430`), and datacenter topology (cabinet, pod, row, slot, rack unit). These agents live in the `hardware-inventory` namespace. When a cluster is requested, the template specifies how many nodes of which resource class to select. The Ansible playbooks **select appropriate agent resources and label them with the cluster order name** -- this label marks them as usable by the NodePool. After selection, agents go through installation stages: rebooting, writing image to disk, and done.
7. **Configures network isolation** -- each cluster gets its own isolated network, created via OpenStack APIs:
   - An **OpenStack network** (isolated L2 segment, e.g., `network-order-nbjgq`)
   - A **subnet** for IP allocation and DHCP (e.g., `192.168.48.0/22`). Clusters use **private address space** internally.
   - A **router** for external egress/ingress
   - After agents are selected, they are **moved onto the new network** before being marked available to the cluster
   - **Two floating IPs** per cluster: one for the Kubernetes API (port-forwarded to a MetalLB-managed address on the management cluster) and one for ingress (port-forwarded to worker node ports 80/443)
   - All OpenStack resources are tagged with `cloudkit` for tracking. MetalLB handles ingress inside the cluster.

   > **Known limitation:** The ingress floating IP forwards to a single worker node. If that node goes down, services are inaccessible even though the cluster is otherwise healthy. This is a known limitation planned for future improvement.
8. **Runs `postinstall.yaml`** -- sets up OAuth, installs operators, applies security policies

### Scale Operations (already implemented)

Scaling is supported today and was demonstrated in POC 3:

```bash
# Scale out: edit cluster to change node count
fulfillment-cli edit cluster <cluster-id>
# Change spec.node_sets.fc430.size from 2 to 3

# The NodePool auto-scales: "Scaling up MachineSet to 3 replicas (actual 2)"
# A new bare metal agent is assigned, provisioned, and joins the cluster
# To scale in, edit the size back down (e.g., 3 to 2)
```

The detailed flow for scale operations:

- **Scale-up:** Editing the cluster via the fulfillment API increases the node count, which updates the ClusterOrder CR. The change is immediately reflected in the cluster order resource on the management cluster. This triggers an Ansible webhook, and the Ansible playbook updates the NodePool, labels a new agent with the cluster order name, and the agent goes through the standard installation stages (rebooting, writing image to disk, done) before joining the cluster.
- **Scale-down:** The same edit process reduces the node count. The agent is unlabeled and removed from the cluster, and the NodePool scales down accordingly.

This is relevant for the quota feature -- scale operations change resource consumption and must be accounted for.

### Step 5: Operator Monitors Status

The OSAC Operator continuously watches the `HostedCluster` resource and updates the ClusterOrder status:

- Waits for `HostedControlPlaneAvailable` condition
- Monitors `NodePool` readiness (worker nodes joined and healthy)
- Tracks overall cluster phase: `Progressing` -> `Ready` or `Failed`
- Records API URL and console URL when available

### Step 6: Fulfillment Service Picks Up Status

The Fulfillment Service watches the ClusterOrder CR on the Hub and syncs status changes back to PostgreSQL. When the cluster becomes `Ready`, the database record is updated with:
- State: `READY`
- API URL: `https://api.my-cluster.example.com:6443`
- Console URL: `https://console-openshift-console.apps.my-cluster.example.com`

### Step 7: User Gets Their Cluster

```bash
# Check status
fulfillment-cli get cluster <id>
# State: READY

# Download kubeconfig
fulfillment-cli get kubeconfig <id> > kubeconfig.yaml

# Use the cluster
export KUBECONFIG=kubeconfig.yaml
oc get nodes
```

### The Complete Flow Diagram

```
User (CLI/UI)
     |
     | 1. Create cluster request
     v
Fulfillment Service
     |
     | 2. Validate, schedule to Hub, store in PostgreSQL
     | 3. Create ClusterOrder CR on Hub
     v
OSAC Operator (on Hub)
     |
     | 4. Reconcile: create namespace, SA, RBAC
     | 5. Trigger AAP (webhook or REST)
     v
AAP (Ansible)
     |
     | 6. Run template role (install.yaml)
     | 7. Create HostedCluster + NodePool
     | 8. Provision bare metal via ESI
     | 9. Configure networking
     | 10. Run postinstall.yaml
     v
ESI / Ironic
     |
     | 11. Lease nodes, attach L2 networks, PXE boot
     v
Bare Metal Hosts join cluster as worker nodes
     |
     | 12. HostedCluster becomes Ready
     v
OSAC Operator
     |
     | 13. Update ClusterOrder status -> Ready
     v
Fulfillment Service
     |
     | 14. Sync status to PostgreSQL
     v
User
     |
     | 15. Get kubeconfig, use cluster
```

### Deletion Flow

Deletion follows the reverse path:

1. User calls `fulfillment-cli delete cluster <id>`
2. Fulfillment Service marks the ClusterOrder for deletion
3. OSAC Operator detects deletion, sets phase to `Deleting`
4. Operator triggers AAP deletion playbook
5. AAP runs `delete.yaml`: removes HostedCluster, deallocates bare metal, cleans up networking
6. Operator removes finalizer, ClusterOrder is deleted
7. Fulfillment Service removes the record from PostgreSQL

---

## 7. ColdFront and Resource Allocation

### What ColdFront Is

**ColdFront** is an open-source resource allocation management tool developed at the University at Buffalo. It is the system that MOC uses to manage quotas and resource allocations across *all* of its platforms.

ColdFront is NOT part of OSAC. It is an independent web application that MOC runs to answer the question: "How much of each resource is this research group allowed to use?"

### How ColdFront Works

ColdFront uses a **push model** with platform-specific plugins:

```
PI/Admin                     ColdFront                    Platform
+--------+                   +----------+                 +-----------+
| Request |  --- submit --->  | Approve  |  --- plugin --> | Set Quota |
| alloc.  |                   | / Deny   |   pushes quota  |           |
+--------+                   +----------+                 +-----------+
```

When a principal investigator (PI) requests resources, a ColdFront administrator approves the allocation, and ColdFront pushes the quota limits to the appropriate platform via plugins.

### Existing ColdFront Plugins

ColdFront already has plugins for several MOC platforms:

| Plugin | What It Does |
|--------|-------------|
| **OpenShift plugin** | Creates a `ResourceQuota` object in the tenant's namespace on OpenShift |
| **OpenStack plugin** | Calls the OpenStack quota API to set compute/network/storage limits |
| **SLURM plugin** | Sets SLURM account resource limits |

### ColdFront Uses CILogon

ColdFront authenticates users via **CILogon**, a federated identity service used by research institutions. This is separate from the GitHub OAuth used for OSAC cluster access and the Keycloak used for the Fulfillment Service API.

### How OSAC Fits In

A proposed OSAC plugin for ColdFront would push quota allocations to OSAC's Quota Service API (see Section 10). But the existing plugins for OpenShift, OpenStack, and SLURM are NOT pre-OSAC features that will become obsolete -- they serve different user populations accessing different platforms.

> **Common Misconception:** "Once OSAC has quota management, ColdFront's other plugins will be replaced." No. A researcher who just needs a VM uses OpenStack directly. A team that needs a k8s namespace uses OpenShift directly. ColdFront manages quotas for ALL of these independently. OSAC is one more platform that ColdFront pushes quotas to.

Here is how different use cases map to different access paths:

| Use Case | Access Path | ColdFront Plugin |
|----------|-------------|------------------|
| VM for a web application | OpenStack directly | OpenStack plugin |
| Kubernetes namespace for a microservice | OpenShift directly | OpenShift plugin |
| Full GPU cluster for ML training | OSAC | OSAC plugin (proposed) |
| Batch HPC job (training run) | SLURM | SLURM allocation |
| Raw bare metal server | ESI directly | ESI allocation |

---

## 8. Multi-Tenancy Model

Multi-tenancy is central to OSAC's design. Without it, you just have a single-user cluster provisioning script.

### What "Tenant" Means in OSAC

A tenant is an organization, research group, or business unit that gets isolated access to cloud resources. At MOC, a tenant might be a university department, a research lab, or an industry partner.

Tenants need isolation at every level:

| Layer | Isolation Mechanism |
|-------|-------------------|
| **Network** | L2-level separation -- each tenant's resources are on dedicated VLANs. No cross-tenant traffic at the switch level. |
| **Compute** | Dedicated bare metal nodes leased from ESI. Control plane isolation via separate HyperShift deployments. |
| **Storage** | Per-cluster storage pools with separate credentials |
| **API** | Fulfillment Service enforces tenant scoping on every query |
| **Database** | PostgreSQL records include a `tenants[]` array with GIN indexes -- every query is automatically filtered |

### Database-Level Isolation

The Fulfillment Service's PostgreSQL schema enforces multi-tenancy at the data layer. Every resource record includes a `tenants` array that lists which tenants can see it. Queries use GIN indexes on this array for efficient filtering:

```sql
-- Every query includes this filter automatically
WHERE tenants @> ARRAY['tenant-id']
```

This means even if there's a bug in the application layer, a tenant cannot see another tenant's resources through raw database queries.

### RBAC on hypershift1 (The Sudoer Pattern)

The development cluster (hypershift1) uses an interesting RBAC pattern that is worth understanding:

- Developers in the `fulfillment-wg` GitHub team get the `nerc-ops` ClusterRole
- This role provides **cluster-wide read access** to everything (pods, secrets, nodes, CRDs)
- For **write operations**, developers must impersonate `system:admin` using `--as system:admin`

This is analogous to the Unix `sudo` pattern: you can look at everything, but you need to explicitly elevate to make changes.

```bash
# Read -- works directly
oc get pods -n innabox-lars
oc get hostedclusters --all-namespaces

# Write -- requires impersonation
oc create namespace my-namespace --as system:admin
oc apply -k overlays/my-dev --as system:admin
```

### Personas

OSAC defines four key personas:

| Persona | Who They Are | What They Do |
|---------|-------------|-------------|
| **Cloud Provider Admin** | Works for the CSP | Onboards tenants, sets quotas, manages templates, super-user |
| **Cloud Infrastructure Admin** | Works for the CSP | Manages core infrastructure (network, storage, compute), keeps the platform running |
| **Tenant Admin** | Works for the tenant organization | Manages their org's users, quotas, templates, IDP configuration |
| **Tenant User** | Works for the tenant organization | Self-service provisions clusters, VMs, bare metal; manages lifecycle of their resources |

---

## 9. Authentication and Access Control

OSAC involves multiple authentication systems because it integrates with multiple platforms. Here is the complete picture:

### Authentication Layers

```
User
  |
  +-- Fulfillment CLI/UI --> Keycloak (OAuth2/OIDC) --> Fulfillment Service
  |
  +-- oc (OpenShift CLI) --> GitHub OAuth --> OpenShift API (Hub cluster)
  |
  +-- ColdFront web UI --> CILogon --> ColdFront
  |
  +-- OpenStack CLI --> Keystone --> OpenStack/ESI API
```

### Fulfillment Service Auth (Keycloak)

The Fulfillment Service uses **Keycloak** as its identity provider (IDP). Keycloak is the single source of truth for all users and groups in an OSAC deployment:

- **Keycloak groups translate to tenants.** When a Keycloak group is created (e.g., `tenant-one`, `tenant-two`), it maps directly to an OSAC tenant. Users within a group are assigned either a **user or admin role** within that tenant.
- A `realm.json` file is used to preconfigure Keycloak during deployment. The default configuration creates sample tenants (`tenant-one`, `tenant-two`) and a user with access to both.
- Keycloak provisions **five default users**, all with the password `foobar`. These are for development and testing only.
- Users authenticate via OAuth2/OIDC. The CLI obtains a bearer token from Keycloak and includes it in every gRPC/REST request. Provisioning requests require a valid **JWT access token** obtained from the Keycloak server (e.g., via `curl` against the token endpoint).
- Service accounts (used for inter-component communication) also use bearer tokens.
- **Authorino** bridges Keycloak with OSAC. It uses an `AuthConfig` CRD to define authorization policies for the fulfillment API, validating JWT tokens issued by the internal Keycloak instance. Authorino sits in front of the Fulfillment Service as an authentication/authorization proxy.

### OpenShift Cluster Auth (GitHub OAuth)

The Hub cluster (hypershift1) uses **GitHub OAuth** identity providers:
- `osac-project` provider -- restricted to `osac-project/fulfillment-wg` team members
- `ocp-on-nerc` provider -- for NERC infrastructure operators
- **group-sync-operator** syncs GitHub teams to OpenShift groups for RBAC

### GitHub Organization Management (OpenTofu)

The `github-config` repository manages the GitHub organization using **OpenTofu** (open-source Terraform):
- Team membership via CSV files (`members.csv`, `team-members/fulfillment-wg.csv`)
- Repository access permissions
- Branch protection rules

### Getting Access to hypershift1

1. **Link your GitHub account to Red Hat** (for SSO)
2. **Set up a Jira account** (for issue tracking)
3. **Submit a PR to `github-config`:**
   - Add your GitHub username to `members.csv`
   - Add your GitHub username to `team-members/fulfillment-wg.csv`
4. **Wait for group-sync** -- the operator syncs GitHub teams to OpenShift groups periodically
5. **Verify:** `oc auth whoami` should show `fulfillment-wg` in your Groups

> **Common Misconception:** "I have access to the GitHub org, so I should have access to the cluster." Not necessarily. The group-sync-operator syncs from the `ocp-on-nerc` GitHub org. If the `osac-project` org is not also synced, your membership won't be reflected. Check with `oc auth whoami` and ask in Slack if your group membership is missing.

---

## 10. Quota Management (Proposed Feature)

Quota management is a work-in-progress feature tracked in Enhancement Proposal PR #8. It does not exist yet, but understanding its design is important because it touches many parts of the system.

### The Problem

Today, OSAC has no resource limits. Any tenant can request as many clusters, VMs, and bare metal nodes as they want. In a shared academic environment like MOC, this is a recipe for one research group consuming the entire GPU pool before others get a chance.

### Proposed Architecture

The solution introduces a new component -- the **OSAC Quota Service** -- as a separate, pluggable service:

```
Tenant --request--> Fulfillment Service (status=pending) ---------> Operator --> Provisioned
                         |                                               ^
                         v                                               |
                    OSAC Quota Service                                   |
                    +-- resolve resource footprint                       |
                    +-- check tenant usage ledger                        |
                    +-- compare against quota limits                     |
                    +-- APPROVED --> update ledger, set status=approved --+
                    +-- DENIED  --> set status=denied + reason
```

### Key Design Decisions

1. **The Quota Service is a separate component.** It is not built into the Fulfillment Service. This keeps OSAC platform-agnostic -- different deployments can plug in different quota logic or quota data sources.

2. **The approval mechanism is generic.** Two new fields are added to every resource: `approval_status` (pending/approved/denied) and `approval_reason`. This can be used for non-quota approval workflows too (e.g., manual admin approval for large requests).

3. **The Quota Service maintains its own usage ledger.** It records every approval and watches for deletions. It does not query the Fulfillment Service for current usage on every decision.

4. **Quota limits are arbitrary key/value pairs.** Extensible to new resource types without code changes. Example: `{"clusters": 5, "nodes.h100": 20, "nodes.fc430": 10, "vcpus": 100}`.

### The Approval Flow

```
1. Request arrives at Fulfillment Service
2. Fulfillment Service creates resource with approval_status = "pending"
3. Quota Service watches for pending resources
4. Quota Service resolves the resource footprint (what will this actually consume?)
5. Quota Service checks tenant's usage ledger against their quota limits
6. If within limits: set approval_status = "approved", update ledger
7. If over limits: set approval_status = "denied", set approval_reason
8. OSAC Operator only processes approved resources
```

> **Key Insight:** If the Quota Service is down, ALL requests stay pending (nothing gets through). This is "safe by default" -- a failure in the quota system cannot cause over-consumption. But it also means the Quota Service needs to be highly available, because its downtime blocks all provisioning.

### The Resource Resolution Problem

This is the critical unsolved prerequisite. Before the Quota Service can check whether a request fits within a tenant's quota, it needs to know: "What resources does this request actually consume?"

For example, the template `ocp_4_17_small` creates a cluster with 2 `fc430` worker nodes. But this mapping from template to resource consumption currently lives only inside the Ansible role -- there is no API that can answer "what will this template consume?" without actually running the playbook.

Three options are under discussion:

| Option | Approach | Assessment |
|--------|---------|-----------|
| **Resolution API** | Fulfillment Service exposes an endpoint that resolves a request into resource requirements | Clean, but new API to build |
| **Direct Inspection** | Quota Service reads request spec and calculates resources itself | Tight coupling, duplicates template logic |
| **Independent Resolution Service** | Extract template resolution into a reusable service | Architecturally strongest, serves quota + billing + UI, but most upfront work |

Option 3 is the recommended approach: template resolution is not a quota concern but a platform capability needed by quotas, billing, UI previews, and capacity planning.

### Known Technical Concerns

| Concern | Details |
|---------|---------|
| **Race conditions** | Two concurrent requests from the same tenant could both pass quota checks before either is recorded. Mitigation: database-level row locking or optimistic concurrency on tenant usage records. |
| **Consistency under failure** | If provisioning fails after approval, the ledger says "consumed" but nothing was actually provisioned. The Quota Service needs a failure feedback loop. |
| **Ledger drift** | If deletion events are missed (network issues, manual `kubectl delete` bypassing the API), the ledger drifts from reality. Reconciliation should be mandatory, not optional. |
| **No "failed" state** | The proposal only defines pending/approved/denied. There is no mechanism for the Quota Service to detect provisioning failure and revert the ledger entry. |

### ColdFront Integration

For MOC, the quota data source is ColdFront. The proposed integration:

1. ColdFront admin approves a resource allocation for a research group
2. ColdFront's OSAC plugin pushes quota limits to the OSAC Quota Service API
3. Quota Service stores the limits and uses them for approval decisions

This mirrors how the existing ColdFront plugins push quotas to OpenShift (`ResourceQuota`) and OpenStack (quota API).

---

## 11. Development Environment

### The Three Testing Layers

| Layer | Environment | What It Tests | Speed |
|-------|-------------|---------------|-------|
| **Unit tests** | Local machine (no cluster) | Logic, parsing, state machines | Seconds |
| **Integration tests** | Local KIND cluster | API contracts, auth, multi-tenancy, database interactions | Minutes |
| **E2E tests** | hypershift1 (personal stack) | Full provisioning with real VMs/clusters/bare metal | Minutes to hours |

### Layer 1: Unit Tests

Run these locally, no cluster required:

```bash
# Fulfillment service (~85 test files, Ginkgo/Gomega)
cd fulfillment-service && ginkgo run -r internal

# Fulfillment CLI (~18 test files)
cd fulfillment-cli && ginkgo run -r

# OSAC operator (~18 test files)
cd osac-operator && make test

# AAP playbooks (linting only)
cd osac-aap && uv run ansible-lint

# UI (Jest)
cd osac-ui && npm test
```

### Layer 2: Integration Tests (KIND Cluster)

The fulfillment-service has comprehensive integration tests that spin up a full environment in a local KIND cluster: PostgreSQL, Keycloak, gRPC server, REST gateway.

```bash
cd fulfillment-service

# Required: add /etc/hosts entries
echo '127.0.0.1 keycloak.keycloak.svc.cluster.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 fulfillment-api.osac.svc.cluster.local' | sudo tee -a /etc/hosts

# Run all integration tests (Helm mode)
IT_DEPLOY_MODE=helm ginkgo run -v it

# Run all integration tests (Kustomize mode)
IT_DEPLOY_MODE=kustomize ginkgo run -v it

# Set up environment for manual testing (keep cluster running)
IT_KEEP_KIND=true ginkgo run --label-filter setup it

# Manual testing against local environment
./fulfillment-cli login fulfillment-api.osac.svc.cluster.local:8000 --plaintext

# Cleanup
kind delete cluster --name fulfillment-service-it
```

**Important limitation:** The KIND environment runs only the Fulfillment Service API layer. There is no operator, no AAP, no OCP-Virt. Requests are accepted and stored but never actually provisioned. This is sufficient for testing API contracts, authentication, multi-tenancy, and database interactions.

### Layer 3: E2E Tests (hypershift1)

For cross-component features or anything involving actual provisioning, you need a personal OSAC stack on hypershift1.

#### Prerequisites Installation Order

On a fresh cluster (not hypershift1, which already has these), prerequisites must be installed in a specific order. CRDs must exist before resources that reference them:

```
1. trust-manager          (certificate trust management)
2. cert-manager           (TLS certificate automation)
3. ca-issuer              (certificate authority configuration)
4. authorino-operator     (API authorization)
5. aap-installation       (Ansible Automation Platform operator)
6. keycloak               (identity and access management)
7. vmaas-components       (KubeVirt/OpenShift CNV for VMs — must apply twice if CRDs aren't ready)
8. nfs-subdir-provisioner (storage for VM live migration)
```

**Certificate architecture:** cert-manager creates and manages TLS certificates across the cluster. trust-manager ensures all workloads trust certificates from the internal CA. All application certificates reference a ClusterIssuer named `default-ca`, which signs every certificate in the OSAC solution. These prerequisites may already be installed on existing clusters -- check with the cluster admin before installing them.

**VMaaS storage requirements:** Compute instances (VMs) require both storage and OpenShift Virtualization. An NFS storage provider is used for centralized storage management and enables **live migration** (L2 migration) of VMs between worker nodes. Users deploying on a new cluster need to create their own overlay to initialize an NFS mount point or configure another suitable storage provider.

> **Common issue:** The vmaas-components manifest references the `HyperConverged` CRD which is created by the CNV operator. If the operator hasn't finished installing, the first `oc apply` will fail with "no matches for kind HyperConverged". Wait for the operator to install, then apply again.

#### Deploying Your Personal Stack

```bash
cd osac-installer

# Create your overlay
cp -r overlays/development overlays/<your-name>

# Edit kustomization.yaml:
#   - Set namespace: <your-name>  (e.g., zszabo-osac)
#   - Update image digests/tags if testing custom builds

# Edit prefixTransformer.yaml:
#   - Set namePrefix: <your-prefix>-  (e.g., zszabo-)

# Add required secrets:
#   overlays/<your-name>/files/license.zip          -- AAP license
#   overlays/<your-name>/files/quay-pull-secret.json -- Registry credentials

# Deploy (write operations require --as system:admin)
oc apply -k overlays/<your-name> --as system:admin

# Monitor
oc get pods -n <your-namespace>

# Your route:
# fulfillment-api-<your-namespace>.apps.hypershift1.nerc.mghpcc.org
```

After applying the OSAC stack overlay, OpenShift begins reconciling objects -- this takes time as operators initialize, databases start, and services come up. The system is ready when the **AAP bootstrap job completes successfully**. The bootstrap job handles template discovery (scanning available Ansible collections for templates and publishing their metadata to the fulfillment service) and initial configuration. Monitor the job in the AAP web UI or by checking pod status in your namespace.

#### Running E2E Tests

```bash
cd osac-test-infra

# Test hub creation lifecycle
ansible-playbook playbooks/test_hub_creation.yml \
  -e test_hub_id=my-test-hub \
  -e test_namespace=<your-namespace>

# Test VM creation lifecycle (create -> poll -> Running -> delete)
ansible-playbook playbooks/test_compute_instance_creation.yml \
  -e test_compute_instance_id=my-test-ci \
  -e test_namespace=<your-namespace>

# Test VM restart
ansible-playbook playbooks/test_compute_instance_restart.yml \
  -e test_namespace=<your-namespace>

# Test deletion during provisioning (cancellation + crash recovery)
ansible-playbook playbooks/test_compute_instance_delete_during_provision.yml \
  -e test_namespace=<your-namespace>
```

### The hypershift1 Cluster

| Property | Value |
|----------|-------|
| Console | `https://console.apps.hypershift1.nerc.mghpcc.org` |
| API | `api.hypershift1.nerc.mghpcc.org:6443` |
| OpenShift Version | 4.18.x |
| Nodes | 3 control-plane + 3 workers |

Pre-installed infrastructure:

| Component | Namespace | Notes |
|-----------|-----------|-------|
| RHACM | `open-cluster-management` | Cluster management |
| HyperShift | `hypershift` | Hosted control planes |
| OCP-Virt (KubeVirt) | `openshift-cnv` | VM support |
| AAP Operator | `aap` | Cluster-scoped |
| Authorino | `authorino-operator` | API auth |
| Cert-Manager | Various | TLS certificates |
| Storage | Various | Ceph RBD (default), NFS (`nfs-vm-dynamic`), LVM |
| VM Images | `openshift-virtualization-os-images` | RHEL 7-10, Fedora, CentOS, Windows |

### When to Use Which Environment

| Scenario | Environment | Why |
|----------|-------------|-----|
| Unit/integration tests | Local (KIND) | Fast, isolated, no cluster needed |
| Component-only development | Local (KIND) | Full API testing without provisioning |
| VMaaS features | hypershift1 (personal stack) | OCP-Virt is pre-installed |
| CaaS features | hypershift1 + ESI bare metal | Requires bare metal nodes |
| Bare metal testing | Request nodes from ESI contacts | Contact `@tzumainn` and `@larsks` in Slack |

### Recommended Development Workflow

**For component-only changes** (CLI commands, service logic, operator controller):
1. Implement and unit test locally
2. Integration test locally (KIND)
3. Submit PR -- CI runs full automated suite

**For cross-component or provisioning features:**
1. Implement and unit test locally
2. Integration test locally where possible
3. Build custom images, push to your Quay registry
4. Deploy personal stack on hypershift1
5. Run E2E tests against your stack
6. Submit PR

> **Common Misconception:** "I should set up the full OSAC stack on my local machine." Do not do this. The full stack (OCP + RHACM + OCP-Virt + AAP + OSAC) requires more resources than typical dev machines. Beaker edge hosts with 64 GiB RAM struggle with heavy swap pressure. Use hypershift1 for anything beyond component-level testing.

> **Note:** OSAC is not limited to MGHPCC/hypershift1. The installation demo (`OSAC_Install_V2.mp4`) shows deployment on a Red Hat edge server (`rdu-infra-edge-02`), demonstrating that OSAC can run on any OCP cluster with the right prerequisites. The POC 3 demo (`poc3-demo-v3.mp4`) shows the full cluster provisioning lifecycle including scale-out/in on the MOC bare metal pool.

---

## 12. Repository Map

### Core Application Repositories

| Repository | Purpose | Language | Key Paths |
|------------|---------|----------|-----------|
| `fulfillment-api/` | Protocol Buffer/gRPC API definitions | Proto/Python | `proto/fulfillment/v1/` |
| `fulfillment-service/` | API server implementation | Go | `cmd/`, `internal/`, `it/` |
| `fulfillment-cli/` | Command-line client | Go | `cmd/` |
| `fulfillment-common/` | Shared code between fulfillment components | Go | |
| `osac-operator/` | Kubernetes operator for managing CRDs | Go | `api/v1alpha1/`, `internal/controller/` |
| `osac-aap/` | Ansible playbooks, roles, and EDA rulebooks | Ansible/Python | `playbook_*.yml`, `rulebooks/` |
| `osac-templates/` | Ansible collection with infrastructure templates | Ansible | `roles/` |
| `osac-ui/` | Web-based management console | TypeScript/React | `src/` |

### Infrastructure and Deployment

| Repository | Purpose |
|------------|---------|
| `osac-installer/` | Kustomize overlays for deploying OSAC stacks |
| `osac-operator-config/` | Operator configuration and manifests |
| `osac-aap-ee/` | AAP Execution Environment container definitions |
| `managed-cluster-config/` | GitOps configuration for managed clusters (ArgoCD) |
| `managed-cluster-apps/` | Applications deployed to managed clusters |
| `osac-massopencloud-templates/` | MOC-specific template customizations |

### Documentation and Organization

| Repository | Purpose |
|------------|---------|
| `docs/` | Architecture documentation, design docs |
| `enhancement-proposals/` | Design proposals for new features (EP process) |
| `issues/` | Central issue tracking across all repositories |
| `github-config/` | GitHub organization configuration (OpenTofu) |
| `osac-test-infra/` | Ansible-based end-to-end test playbooks |

### Directory Structure

```
/home/zszabo/projects/osac/
+-- docs/                          # Main documentation
|   +-- architecture/              # Architecture docs (cluster/VM/BM fulfillment)
+-- fulfillment-api/
|   +-- proto/fulfillment/v1/      # gRPC/protobuf API definitions
+-- fulfillment-service/
|   +-- cmd/                       # CLI entry points
|   +-- internal/                  # Business logic
|   +-- manifests/                 # K8s deployment manifests
|   +-- it/                        # Integration tests
+-- osac-operator/
|   +-- api/v1alpha1/              # CRD type definitions
|   +-- internal/controller/       # Controller reconciliation logic
|   +-- config/                    # Kustomize configs (CRDs, RBAC, manager)
+-- osac-aap/
|   +-- playbook_*.yml             # Main provisioning playbooks
|   +-- rulebooks/                 # EDA event-to-action rules
|   +-- vendor/                    # Vendored Ansible collections
+-- osac-installer/
|   +-- overlays/                  # Per-environment Kustomize overlays
+-- managed-cluster-config/
|   +-- cluster-scope/overlays/    # Cluster-specific configurations
+-- osac-test-infra/
|   +-- playbooks/                 # E2E test playbooks
|   +-- roles/                     # Test helper roles
+-- enhancement-proposals/
    +-- enhancements/              # Individual enhancement proposals
```

---

## 13. Key Technologies Reference

| Component | Technologies |
|-----------|-------------|
| **fulfillment-service** | Go 1.22+, gRPC, gRPC-Gateway (REST), PostgreSQL (JSONB), Ginkgo/Gomega |
| **osac-operator** | Go 1.22+, Kubebuilder, controller-runtime, Kubernetes CRDs |
| **fulfillment-cli** | Go, cobra (CLI framework), OAuth2 |
| **fulfillment-api** | Protocol Buffers (proto3), gRPC-Gateway, buf (linting/generation) |
| **osac-aap** | Ansible, Event-Driven Ansible (EDA), uv (Python package manager) |
| **osac-ui** | React 18, TypeScript, PatternFly 6 (Red Hat design system), Vite |
| **osac-installer** | Kustomize, Kubernetes |
| **managed-cluster-config** | Kustomize, GitOps/ArgoCD |
| **github-config** | OpenTofu (open-source Terraform) |
| **Hub infrastructure** | OpenShift 4.18, RHACM 2.18+, HyperShift, OCP-Virt 4.17+, AAP 2.5+ |
| **Bare metal mgmt** | OpenStack Ironic (ESI), L2/L3 networking, PXE boot |
| **Auth** | Keycloak (OIDC), Authorino, GitHub OAuth, CILogon |
| **Storage** | Ceph RBD, NFS, LVM |

---

## 14. Common Tasks and Troubleshooting

### Debug a Failed Cluster

```bash
# 1. Check ClusterOrder status on the Hub
oc get clusterorder <name> -o yaml

# 2. Check HostedCluster status
oc get hostedcluster -n <cluster-namespace> -o yaml

# 3. Check operator logs
oc logs deployment/<prefix>-controller-manager -n <namespace> --tail=200

# 4. Check AAP job logs (find the AAP route first)
oc get route -n <namespace> | grep aap
# Then open the AAP web UI and check job status

# 5. Check events for clues
oc get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

### Debug a Failed VM

```bash
# Check ComputeInstance status
oc get computeinstance <name> -o yaml

# Check VirtualMachineInstance status
oc get vmi -n <namespace> -o yaml

# Check KubeVirt events
oc get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

### Rebuild and Redeploy a Component

```bash
# Fulfillment service
cd fulfillment-service
podman build -t quay.io/<user>/fulfillment-service:dev .
podman push quay.io/<user>/fulfillment-service:dev
oc set image deployment/fulfillment-service \
    server=quay.io/<user>/fulfillment-service:dev -n <namespace> --as system:admin

# Operator
cd osac-operator
make image-build image-push IMG=quay.io/<user>/osac-operator:dev
make deploy IMG=quay.io/<user>/osac-operator:dev
```

### Run Local Integration Environment

```bash
cd fulfillment-service

# Add hosts entries (one-time)
echo '127.0.0.1 keycloak.keycloak.svc.cluster.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 fulfillment-api.osac.svc.cluster.local' | sudo tee -a /etc/hosts

# Setup environment without running tests
IT_KEEP_KIND=true ginkgo run --label-filter setup it

# Manual testing
kubectl get pods -A
grpcurl -plaintext \
    -H "Authorization: Bearer $(kubectl create token client -n osac)" \
    fulfillment-api.osac.svc.cluster.local:8000 \
    fulfillment.v1.ClusterTemplates/List
```

### Common Issues

| Issue | Likely Cause | Solution |
|-------|-------------|---------|
| `ImagePullBackOff` | Invalid registry credentials | Check pull secrets in namespace |
| Certificate errors | cert-manager not ready | Check cert-manager pods and certificate issuer status |
| ClusterOrder stuck in `Progressing` | AAP job failed | Check AAP job logs in the web UI |
| gRPC connection refused | Service not running | Check fulfillment-service pods and service endpoints |
| OAuth login fails | Not in GitHub team | Verify team membership in `github-config`, wait for group-sync |
| `--as system:admin` rejected | Group not synced | Run `oc auth whoami` and check for `fulfillment-wg` group |
| KIND tests fail | Missing /etc/hosts entries | Add the two host entries listed above |

### Debug Commands Reference

```bash
# Certificate status
oc describe certificate -n <namespace>

# All events (sorted by time)
oc get events -n <namespace> --sort-by=.metadata.creationTimestamp

# Service endpoints (are backends registered?)
oc get endpoints -n <namespace>

# Fulfillment service logs
oc logs -n <namespace> deployment/fulfillment-service -c server --tail=500

# Operator logs
oc logs -n <namespace> deployment/<prefix>-controller-manager --tail=500

# EDA activation logs
oc logs -n <namespace> deployment/<prefix>-eda-activation --tail=500
```

### CI/CD Pipeline

PRs to core repositories automatically trigger:

1. **Pre-commit checks** -- code formatting (gofmt), linting
2. **Generated code validation** -- buf checks for proto definitions
3. **Unit tests** -- ginkgo/gomega, jest
4. **Integration tests** -- both Helm and Kustomize deployment modes
5. **Container image build** -- on merge to main

---

## Appendix: Glossary

| Term | Definition |
|------|-----------|
| **AAP** | Ansible Automation Platform -- executes provisioning playbooks |
| **CaaS** | Cluster-as-a-Service -- OSAC's cluster provisioning offering |
| **ColdFront** | Open-source resource allocation management tool used at MOC |
| **CR** | Custom Resource -- a Kubernetes object defined by a CRD |
| **CRD** | Custom Resource Definition -- extends the Kubernetes API with new object types |
| **CSP** | Cloud Service Provider -- the organization running OSAC |
| **EDA** | Event-Driven Ansible -- triggers playbooks in response to events |
| **ESI** | Elastic Secure Infrastructure -- OpenStack Ironic with multi-tenancy |
| **HCP** | Hosted Control Planes -- HyperShift's architecture for running control planes as pods |
| **Hub** | Management Cluster -- the OpenShift cluster that runs OSAC and hosts tenant control planes |
| **HyperShift** | Red Hat technology for hosting OpenShift control planes as pods on a management cluster |
| **KubeVirt** | Kubernetes-native virtualization (runs VMs as pods); basis of OCP-Virt |
| **MGHPCC** | Massachusetts Green High Performance Computing Center -- the datacenter in Holyoke, MA |
| **MOC** | Mass Open Cloud -- multi-university cloud partnership |
| **NERC** | New England Research Cloud -- the production MOC environment |
| **OCP-Virt** | OpenShift Virtualization -- Red Hat's productization of KubeVirt |
| **RHACM** | Red Hat Advanced Cluster Management -- manages multiple OpenShift clusters |
| **VMaaS** | VM-as-a-Service -- OSAC's virtual machine provisioning offering |

---

*This guide was written to complement `CLAUDE.md` (the developer reference) and the Enhancement Proposals in the `enhancement-proposals/` repository. For command-by-command details, see `CLAUDE.md`. For feature design discussions, see the Enhancement Proposals. For this guide's quota management details, see `quota-feature-project-plan.md`.*
