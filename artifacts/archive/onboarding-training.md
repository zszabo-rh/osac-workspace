# OSAC Onboarding Training Guide

Welcome to the Open Sovereign AI Cloud (OSAC) project! This guide will help you understand the project from the ground up, starting with fundamental concepts and progressively moving to detailed implementation specifics.

---

## Table of Contents

1. [Introduction: What is OSAC?](#1-introduction-what-is-osac)
2. [Key Concepts and Terminology](#2-key-concepts-and-terminology)
3. [High-Level Architecture Overview](#3-high-level-architecture-overview)
4. [The Repository Landscape](#4-the-repository-landscape)
5. [Core Component Deep Dive](#5-core-component-deep-dive)
6. [The Fulfillment Workflow](#6-the-fulfillment-workflow)
7. [Templates: The Heart of Automation](#7-templates-the-heart-of-automation)
8. [Development Environment Setup](#8-development-environment-setup)
9. [Working with the Codebase](#9-working-with-the-codebase)
10. [Testing and Quality Assurance](#10-testing-and-quality-assurance)
11. [Deployment and Operations](#11-deployment-and-operations)
12. [Contributing to OSAC](#12-contributing-to-osac)
13. [Common Tasks and Recipes](#13-common-tasks-and-recipes)
14. [Troubleshooting Guide](#14-troubleshooting-guide)
15. [Additional Resources](#15-additional-resources)

---

## 1. Introduction: What is OSAC?

### The Problem OSAC Solves

There is a worldwide trend towards **Sovereign AI Clouds (SACs)**, where countries and corporations want to have their own clouds with their own rules. These organizations need:

- Complete control over their infrastructure
- Compliance with local regulations (like GDPR)
- Self-service provisioning for their users
- Scalable, production-ready solutions

### What OSAC Provides

**Open Sovereign AI Cloud (OSAC)** is an open-source solution that enables organizations to stand up their own clouds. It provides:

1. **A complete set of technologies and components** - Everything needed to run a cloud
2. **Prescriptive, validated configurations** - Only tested, working combinations
3. **Self-service infrastructure provisioning** - Users can provision resources on-demand
4. **Multi-tenancy** - Multiple isolated organizations on shared infrastructure

### What Can Users Provision?

OSAC enables self-service provisioning of:

- **OpenShift Clusters** - Complete Kubernetes clusters with hosted control planes
- **Virtual Machines** - VMs on OpenShift Virtualization
- **Bare Metal Servers** (under development) - Dedicated physical servers
- **Higher-level services** (planned) - Model-as-a-Service, OpenShift AI, etc.

### Where is OSAC Deployed?

OSAC is being developed and continuously deployed at the **Mass Open Cloud (MOC)**, a public computing cloud that provides:
- Real-world scale for testing
- A public environment for partners to integrate hardware/services
- Production workloads with actual AI users

---

## 2. Key Concepts and Terminology

Before diving deeper, let's establish the vocabulary used throughout OSAC:

### Personas

| Persona | Description |
|---------|-------------|
| **Cloud Provider Admin** | Works for the cloud provider, manages tenant onboarding, quotas, and global templates |
| **Cloud Infrastructure Admin** | Manages core infrastructure (network, compute, storage), ensures cloud services are running |
| **Tenant Admin** | Works for a tenant organization, manages their org's users, quotas, and templates |
| **Tenant User** | End user who provisions cloud resources for themselves or their team |

### Core Terms

| Term | Definition |
|------|------------|
| **Tenant** | A user or group with ability to self-service provision clusters; acts as cluster admin for their own clusters |
| **Tenant Cluster** | A running OpenShift cluster requested by a tenant |
| **Management Cluster** | An OpenShift cluster with management tooling that provisions and manages tenant infrastructure |
| **Hub** | A registered Management Cluster that the Fulfillment Service can schedule work to |
| **Template** | An Ansible Role that defines how to provision a specific type of infrastructure |
| **ClusterOrder** | A Kubernetes Custom Resource that represents a request to provision a cluster |
| **ComputeInstance** | A Kubernetes Custom Resource that represents a request for a virtual machine |
| **HCP (Hosted Control Planes)** | Architecture where cluster control planes run as pods, separate from worker nodes |
| **ACM** | Advanced Cluster Management - Red Hat product for provisioning/managing multiple clusters |
| **AAP** | Ansible Automation Platform - Executes provisioning workflows |
| **EDA** | Event Driven Ansible - Triggers Ansible in response to events |

---

## 3. High-Level Architecture Overview

OSAC's architecture consists of several layers working together:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACES                                 │
│                                                                             │
│    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                │
│    │   OSAC UI    │    │Fulfillment   │    │  Custom UIs  │                │
│    │  (Web App)   │    │    CLI       │    │  (CSP Built) │                │
│    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                │
│           │                   │                   │                         │
└───────────┼───────────────────┼───────────────────┼─────────────────────────┘
            │                   │                   │
            ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FULFILLMENT SERVICE                                  │
│                                                                             │
│    ┌─────────────────────────────────────────────────────────────┐         │
│    │  REST/gRPC API  │  PostgreSQL  │  Hub Scheduler  │ Auth    │         │
│    └─────────────────────────────────────────────────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Creates ClusterOrder/ComputeInstance CRs
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MANAGEMENT CLUSTER (Hub)                                │
│                                                                             │
│    ┌───────────────────┐    ┌───────────────────┐    ┌──────────────────┐  │
│    │   OSAC Operator   │───▶│  Event Driven     │───▶│  AAP Controller  │  │
│    │  (K8s Controller) │    │  Ansible (EDA)    │    │  (Job Templates) │  │
│    └───────────────────┘    └───────────────────┘    └──────────────────┘  │
│              │                                                │              │
│              │ Monitors                          Executes    │              │
│              ▼                                               ▼              │
│    ┌───────────────────┐                        ┌──────────────────────┐   │
│    │  HostedCluster    │                        │  Ansible Templates   │   │
│    │  (HyperShift)     │                        │  (Provisioning)      │   │
│    └───────────────────┘                        └──────────────────────┘   │
│                                                                             │
│    ┌───────────────────────────────────────────────────────────────────┐   │
│    │  RHACM  │  OpenShift Virtualization  │  Networking  │  Storage    │   │
│    └───────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Three Major Components

1. **Fulfillment Service** - The API layer that receives and tracks requests for cloud resources
2. **OSAC Operator** - Kubernetes operator on each Management Cluster that processes requests
3. **Ansible Automation Platform (AAP)** - Executes the actual provisioning steps via templates

### Why This Architecture?

- **Privilege Separation**: External-facing API cannot directly affect infrastructure
- **Multi-tenancy**: Abstraction layer on top of Kubernetes APIs suitable for cloud use cases
- **Security**: Kubernetes API is not suitable for untrusted external clients
- **Topology Awareness**: Support for multiple Management Clusters with scheduling
- **Flexibility**: Any provisioning logic can be implemented in Ansible templates

---

## 4. The Repository Landscape

OSAC is organized into 21 repositories. Here's how they relate:

### Core Application Repositories

| Repository | Purpose | Language |
|------------|---------|----------|
| **fulfillment-api** | Protocol Buffer/gRPC API definitions | Proto/Python |
| **fulfillment-service** | API server implementation | Go |
| **fulfillment-cli** | Command-line client | Go |
| **fulfillment-common** | Shared code between fulfillment components | Go |
| **osac-operator** | Kubernetes operator for managing orders | Go |
| **osac-aap** | Ansible playbooks, roles, and rulebooks | Ansible/Python |
| **osac-templates** | Ansible collection with infrastructure templates | Ansible |
| **osac-ui** | Web-based management console | TypeScript/React |

### Infrastructure and Deployment

| Repository | Purpose |
|------------|---------|
| **osac-installer** | Kustomize-based deployment configurations |
| **osac-operator-config** | Operator configuration and manifests |
| **osac-aap-ee** | AAP Execution Environment container definitions |
| **managed-cluster-config** | Configuration for managed clusters |
| **managed-cluster-apps** | Applications deployed to managed clusters |
| **osac-massopencloud-templates** | MOC-specific template customizations |

### Documentation and Planning

| Repository | Purpose |
|------------|---------|
| **docs** | Architecture and feature documentation |
| **enhancement-proposals** | Design proposals for new features |
| **issues** | Central issue tracking |

### Organization and CI/CD

| Repository | Purpose |
|------------|---------|
| **github-config** | GitHub organization configuration (Terraform/HCL) |
| **.github** | Organization profile and shared workflows |
| **public_template** | Template for new public repositories |
| **osac-test-infra** | Ansible-based end-to-end testing |

### Repository Dependency Graph

```
                    fulfillment-api
                    (Proto definitions)
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
   fulfillment-service   osac-operator  fulfillment-cli
            │             │
            │             ▼
            │        osac-aap ◀──── osac-templates
            │             │
            └──────┬──────┘
                   ▼
              osac-installer
                   │
                   ▼
           Deployed to OpenShift
```

---

## 5. Core Component Deep Dive

### 5.1 Fulfillment API (`fulfillment-api`)

The API is defined using **Protocol Buffers** and **gRPC**, providing both gRPC and REST access.

**Key Proto Files** (`proto/fulfillment/v1/`):
- `cluster_type.proto` - Cluster object definition
- `clusters_service.proto` - CRUD operations for clusters
- `cluster_template_type.proto` - Template definition
- `compute_instance_type.proto` - VM definition
- `host_pool_type.proto` - Host pool management
- `host_type.proto` - Individual host management

**API Services Available**:
```
fulfillment.v1.ClusterOrders     - Manage cluster provisioning requests
fulfillment.v1.ClusterTemplates  - List available cluster templates
fulfillment.v1.Clusters          - Cluster lifecycle management
fulfillment.v1.ComputeInstances  - VM lifecycle management
fulfillment.v1.HostPools         - Manage pools of physical hosts
fulfillment.v1.Hosts             - Individual host management
```

### 5.2 Fulfillment Service (`fulfillment-service`)

A Go application that implements the Fulfillment API.

**Project Structure**:
```
fulfillment-service/
├── cmd/                     # CLI commands
├── internal/
│   ├── api/                 # Generated protobuf code
│   ├── controllers/         # Business logic controllers
│   │   ├── cluster/         # Cluster provisioning logic
│   │   └── compute/         # VM provisioning logic
│   ├── database/            # PostgreSQL integration
│   └── servers/             # gRPC and REST server setup
├── manifests/               # Kubernetes deployment configs
└── it/                      # Integration tests
```

**Key Technologies**:
- **Go 1.22+** - Primary language
- **PostgreSQL** - Persistent state storage
- **gRPC + gRPC-Gateway** - API layer
- **Kustomize** - Kubernetes manifests
- **Ginkgo/Gomega** - Testing framework

**Running Locally**:
```bash
# Start PostgreSQL
podman run -d --name postgresql_database \
  -e POSTGRESQL_USER=user -e POSTGRESQL_PASSWORD=pass -e POSTGRESQL_DATABASE=db \
  -p 127.0.0.1:5432:5432 quay.io/sclorg/postgresql-15-c9s:latest

# Start gRPC server
./fulfillment-service start grpc-server \
    --grpc-listener-address=localhost:8000 \
    --db-url=postgres://user:pass@localhost:5432/db

# Start REST gateway
./fulfillment-service start rest-gateway \
    --http-listener-address=localhost:8001 \
    --grpc-server-address=localhost:8000 \
    --grpc-server-plaintext
```

### 5.3 OSAC Operator (`osac-operator`)

A Kubernetes operator built with **Kubebuilder** that watches for orders and ensures fulfillment.

**Custom Resource Definitions (CRDs)**:

| CRD | Purpose |
|-----|---------|
| `ClusterOrder` | Request to provision an OpenShift cluster |
| `ComputeInstance` | Request to provision a virtual machine |
| `HostPool` | Manage a pool of physical hosts |
| `Tenant` | Represent a tenant organization |

**ClusterOrder Spec** (`api/v1alpha1/clusterorder_types.go`):
```go
type ClusterOrderSpec struct {
    TemplateID         string        // Which template to use
    TemplateParameters string        // JSON-encoded parameters
    NodeRequests       []NodeRequest // Worker node specifications
}

type NodeRequest struct {
    ResourceClass string // Type of node (e.g., "fc430")
    NumberOfNodes int    // How many nodes
}
```

**Controller Flow**:
1. Watch for ClusterOrder creation/updates
2. Create prerequisite resources (namespace, service account, RBAC)
3. Call EDA webhook to trigger Ansible automation
4. Monitor HostedCluster resource created by Ansible
5. Sync status back to ClusterOrder

**Controllers** (`internal/controller/`):
- `clusterorder_controller.go` - Cluster provisioning
- `computeinstance_controller.go` - VM provisioning
- `hostpool_controller.go` - Host pool management
- `tenant_controller.go` - Tenant management
- `feedback_controller.go` - Status synchronization

### 5.4 Ansible Automation Platform (`osac-aap`)

Contains Ansible roles, playbooks, and EDA rulebooks for infrastructure automation.

**Directory Structure**:
```
osac-aap/
├── playbook_cloudkit_create_hosted_cluster.yml    # Cluster creation
├── playbook_cloudkit_delete_hosted_cluster.yml    # Cluster deletion
├── playbook_cloudkit_create_compute_instance.yml  # VM creation
├── playbook_cloudkit_delete_compute_instance.yml  # VM deletion
├── playbook_osac_create_hostpool.yml              # Host pool creation
├── rulebooks/                                      # EDA rulebooks
├── collections/                                    # Ansible collections
├── vendor/                                         # Vendored collections
└── execution-environment/                          # EE definition
```

**EDA Rulebook** (`rulebooks/cluster_fulfillment.yml`):
```yaml
- name: Cluster fulfillment rulebook
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Create cluster on create-hosted-cluster event
      condition: event.meta.endpoint == "create-hosted-cluster"
      action:
        run_workflow_template:
          name: cloudkit-create-hosted-cluster
```

### 5.5 OSAC Templates (`osac-templates`)

An Ansible collection providing infrastructure templates.

**Available Templates**:

| Template | Type | Description |
|----------|------|-------------|
| `ocp_4_17_small` | Cluster | Minimal OpenShift 4.17 cluster |
| `ocp_4_17_small_github` | Cluster | OpenShift 4.17 with GitHub OAuth |
| `ocp_virt_vm` | VM | Configurable virtual machine |

**Template Structure**:
```
roles/ocp_4_17_small/
├── tasks/
│   ├── install.yaml      # Provisioning tasks
│   ├── postinstall.yaml  # Post-installation configuration
│   └── delete.yaml       # Cleanup tasks
├── defaults/
│   └── main.yaml         # Default variable values
└── meta/
    ├── cloudkit.yaml     # Template metadata
    └── argument_specs.yaml # Parameter definitions
```

**Template Metadata** (`meta/cloudkit.yaml`):
```yaml
title: OpenShift 4.17 small
description: OpenShift 4.17 with small instances as worker nodes
template_type: cluster
default_node_request:
  - resourceClass: fc430
    numberOfNodes: 2
```

### 5.6 Fulfillment CLI (`fulfillment-cli`)

Command-line tool for interacting with the Fulfillment API.

**Key Commands**:
```bash
# Authentication
fulfillment-cli login api.example.com:443
fulfillment-cli logout

# Templates
fulfillment-cli get clustertemplates
fulfillment-cli get clustertemplate <id> -o yaml

# Clusters
fulfillment-cli create cluster --template ocp_4_17_small --name my-cluster
fulfillment-cli get clusters
fulfillment-cli describe cluster <id>
fulfillment-cli get kubeconfig <id>
fulfillment-cli delete cluster <id>

# VMs
fulfillment-cli create computeinstance --template ocp_virt_vm --name my-vm
fulfillment-cli get computeinstances
fulfillment-cli delete computeinstance <id>

# Hubs (Management Clusters)
fulfillment-cli create hub --kubeconfig=kubeconfig.hub --id my-hub --namespace osac
fulfillment-cli get hubs
```

### 5.7 OSAC UI (`osac-ui`)

React-based web console built with PatternFly.

**Technology Stack**:
- **React 18** + **TypeScript**
- **PatternFly 6** - Red Hat's design system
- **Vite** - Build tool
- **oidc-client-ts** - Keycloak authentication
- **Axios** + **gRPC-Web** - API communication

**Features**:
- Dashboard with real-time metrics
- VM lifecycle management (create, view, delete)
- Cluster provisioning and monitoring
- Template browsing and selection
- Role-based access control (admin/client roles)

---

## 6. The Fulfillment Workflow

Understanding how a request flows through the system is essential. Let's trace a cluster provisioning request:

### Step-by-Step Cluster Provisioning

```
┌─────────┐     ┌─────────────────┐     ┌────────────────┐     ┌───────────┐
│  User   │────▶│ Fulfillment     │────▶│ Management     │────▶│  Tenant   │
│         │     │ Service         │     │ Cluster        │     │  Cluster  │
└─────────┘     └─────────────────┘     └────────────────┘     └───────────┘
```

**1. User Submits Request**
```bash
fulfillment-cli create cluster --template ocp_4_17_small --name my-cluster
```

**2. Fulfillment Service Receives Request**
- Validates the request and template
- Selects a Management Cluster (Hub) to handle the request
- Creates a `ClusterOrder` CR in a tenant namespace on the selected Hub
- Returns the cluster ID to the user

**3. OSAC Operator Processes ClusterOrder**
- Watches for new ClusterOrder resources
- Sets status to "Progressing"
- Creates prerequisite resources:
  - Namespace for the cluster
  - ServiceAccount for automation
  - RoleBindings for RBAC
- Triggers EDA webhook with ClusterOrder payload

**4. Event Driven Ansible Activates**
- Receives webhook at `/create-hosted-cluster` endpoint
- Launches the cluster creation workflow template in AAP

**5. Ansible Executes Template**
```yaml
# From playbook_cloudkit_create_hosted_cluster.yml
- name: Acquire cluster lock
  ansible.builtin.include_role:
    name: cloudkit.service.lease

- name: Add infrastructure finalizer
  ansible.builtin.include_role:
    name: cloudkit.service.finalizer

- name: Call the selected template
  ansible.builtin.include_role:
    name: "{{ template_id }}"   # e.g., "ocp_4_17_small"
    tasks_from: "install"
```

**6. Template Creates Infrastructure**
- Creates `HostedCluster` resource (HyperShift)
- Creates `NodePool` resources for workers
- Configures networking and ingress
- Waits for control plane availability

**7. Status Flows Back**
- OSAC Operator monitors `HostedCluster` conditions
- Updates `ClusterOrder` status (Progressing → Ready)
- Fulfillment Service syncs status from ClusterOrder
- User can query status via CLI or UI

**8. Cluster Ready**
```bash
# User retrieves kubeconfig
fulfillment-cli get kubeconfig <cluster-id> > kubeconfig.yaml
kubectl --kubeconfig=kubeconfig.yaml get nodes
```

### Sequence Diagram

```
User          CLI           FulfillmentSvc   OSAC-Operator    EDA          AAP
  │            │                 │                │            │            │
  │──create───▶│                 │                │            │            │
  │            │───CreateCluster▶│                │            │            │
  │            │                 │──ClusterOrder─▶│            │            │
  │            │                 │                │            │            │
  │            │◀──cluster-id────│                │            │            │
  │◀──id───────│                 │                │            │            │
  │            │                 │                │            │            │
  │            │                 │                │──webhook──▶│            │
  │            │                 │                │            │──run job──▶│
  │            │                 │                │            │            │
  │            │                 │                │            │◀──status───│
  │            │                 │                │◀──status───│            │
  │            │                 │◀──status──────│            │            │
  │            │                 │                │            │            │
  │──status───▶│                 │                │            │            │
  │            │───GetCluster───▶│                │            │            │
  │◀──Ready────│◀──status────────│                │            │            │
```

---

## 7. Templates: The Heart of Automation

Templates are **Ansible Roles** that define how infrastructure gets provisioned. They are the most customizable part of OSAC.

### Template Anatomy

Every template follows this structure:

```
roles/my_template/
├── tasks/
│   ├── install.yaml       # Create/update infrastructure
│   ├── postinstall.yaml   # Post-creation configuration
│   └── delete.yaml        # Remove infrastructure
├── defaults/
│   └── main.yaml          # Default parameter values
├── vars/
│   └── main.yaml          # Internal variables
└── meta/
    ├── cloudkit.yaml      # OSAC-specific metadata
    └── argument_specs.yaml # Parameter definitions
```

### Template Metadata (`meta/cloudkit.yaml`)

```yaml
title: "My Custom Cluster"
description: "OpenShift cluster with custom configuration"
template_type: cluster  # or 'vm'
default_node_request:
  - resourceClass: fc430
    numberOfNodes: 3
allowed_resource_classes:
  - fc430
  - fc630
```

### Parameter Definitions (`meta/argument_specs.yaml`)

```yaml
argument_specs:
  main:
    short_description: Custom cluster template
    options:
      template_parameters:
        description: Template parameters
        type: dict
        options:
          ocp_version:
            description: OpenShift version
            type: str
            default: "4.17"
          enable_monitoring:
            description: Enable cluster monitoring
            type: bool
            default: true
          worker_memory:
            description: Worker node memory
            type: str
            default: "16Gi"
```

### Creating a Custom Template

**Step 1: Create Directory Structure**
```bash
cd osac-templates/roles
mkdir -p my_custom_cluster/{tasks,defaults,meta}
```

**Step 2: Define Metadata**
```yaml
# meta/cloudkit.yaml
title: "My Custom Cluster"
description: "Production-ready OpenShift cluster with monitoring"
template_type: cluster
default_node_request:
  - resourceClass: fc430
    numberOfNodes: 3
```

**Step 3: Implement Install Tasks**
```yaml
# tasks/install.yaml
---
- name: Create HostedCluster resource
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: hypershift.openshift.io/v1beta1
      kind: HostedCluster
      metadata:
        name: "{{ cluster_order.metadata.name }}"
        namespace: "{{ cluster_working_namespace }}"
      spec:
        release:
          image: "quay.io/openshift-release-dev/ocp-release:{{ template_parameters.ocp_version }}"
        # ... additional configuration

- name: Create NodePool
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: hypershift.openshift.io/v1beta1
      kind: NodePool
      # ...
```

**Step 4: Implement Delete Tasks**
```yaml
# tasks/delete.yaml
---
- name: Delete NodePool
  kubernetes.core.k8s:
    state: absent
    api_version: hypershift.openshift.io/v1beta1
    kind: NodePool
    name: "{{ cluster_order.metadata.name }}"
    namespace: "{{ cluster_working_namespace }}"

- name: Delete HostedCluster
  kubernetes.core.k8s:
    state: absent
    api_version: hypershift.openshift.io/v1beta1
    kind: HostedCluster
    name: "{{ cluster_order.metadata.name }}"
    namespace: "{{ cluster_working_namespace }}"
```

### VM Templates

VM templates work similarly but create `VirtualMachine` resources:

```yaml
# tasks/create.yaml (VM template)
- name: Create VirtualMachine
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: kubevirt.io/v1
      kind: VirtualMachine
      metadata:
        name: "{{ compute_instance.metadata.name }}"
        namespace: "{{ compute_instance_working_namespace }}"
      spec:
        running: true
        template:
          spec:
            domain:
              cpu:
                cores: "{{ template_parameters.cpu_cores | default(2) }}"
              memory:
                guest: "{{ template_parameters.memory | default('2Gi') }}"
            # ...
```

---

## 8. Development Environment Setup

### Prerequisites

- **Go 1.22+** - For fulfillment-service and osac-operator
- **Python 3.12+** - For fulfillment-api and dev tools
- **Node.js 20+** - For osac-ui
- **Podman/Docker** - For container builds
- **kubectl/oc** - For Kubernetes interaction
- **kind** - For local Kubernetes clusters (integration tests)
- **Ansible** - For template development

### Setting Up Each Component

#### Fulfillment Service

```bash
cd fulfillment-service

# Install dependencies
go mod download

# Run unit tests
ginkgo run -r

# Build binary
go build

# Run locally (requires PostgreSQL)
./fulfillment-service start grpc-server --db-url=postgres://user:pass@localhost:5432/db
```

#### OSAC Operator

```bash
cd osac-operator

# Install dependencies
go mod download

# Generate code (after CRD changes)
make generate
make manifests

# Run unit tests
make test

# Build
make build

# Deploy to cluster
make deploy IMG=quay.io/myuser/osac-operator:latest
```

#### Fulfillment API

```bash
cd fulfillment-api

# Create virtual environment with direnv (recommended)
# Or manually:
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up dev tools
./dev.py setup

# Lint the API spec
./dev.py lint

# Generate OpenAPI spec
./dev.py generate
```

#### OSAC AAP

```bash
cd osac-aap

# Install dependencies
uv sync --all-groups

# Activate environment
source .venv/bin/activate

# Run playbooks locally (for testing)
ansible-playbook playbook_test.yml

# Run linters
pre-commit run --all-files
```

#### OSAC UI

```bash
cd osac-ui

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Start dev server
npm run dev

# Build for production
npm run build
```

---

## 9. Working with the Codebase

### Code Style and Standards

**Go Projects** (fulfillment-service, osac-operator, fulfillment-cli):
- Follow standard Go conventions
- Use `gofmt` for formatting
- Run `golangci-lint` for linting
- Tests use Ginkgo/Gomega framework

**Python/Ansible Projects** (fulfillment-api, osac-aap):
- Follow PEP 8 for Python
- Use `ansible-lint` and `yamllint` for Ansible
- Run `pre-commit` hooks before committing

**TypeScript Projects** (osac-ui):
- Use ESLint with TypeScript rules
- Follow React hooks best practices
- PatternFly component conventions

### Making Changes to the API

1. **Modify Proto Files** in `fulfillment-api/proto/fulfillment/v1/`
2. **Generate Code**:
   ```bash
   cd fulfillment-api
   ./dev.py generate
   ```
3. **Update Service Implementation** in `fulfillment-service/internal/`
4. **Update Operator** if needed in `osac-operator/internal/`
5. **Update CLI** if needed in `fulfillment-cli/`

### Adding a New CRD to the Operator

1. **Define Types**:
   ```bash
   cd osac-operator
   # Edit api/v1alpha1/<type>_types.go
   ```

2. **Generate Code**:
   ```bash
   make generate
   make manifests
   ```

3. **Implement Controller**:
   ```bash
   # Create internal/controller/<type>_controller.go
   ```

4. **Register Controller** in `cmd/main.go`

5. **Write Tests** in `internal/controller/<type>_controller_test.go`

### Adding a New Ansible Role to AAP

1. **Create Role Structure**:
   ```bash
   cd osac-aap/vendor/cloudkit/service/roles
   mkdir -p my_role/{tasks,defaults,meta}
   ```

2. **Implement Tasks**:
   ```yaml
   # tasks/main.yaml
   ---
   - name: My task
     # ...
   ```

3. **Define Arguments**:
   ```yaml
   # meta/argument_specs.yaml
   argument_specs:
     main:
       options:
         my_param:
           type: str
           required: true
   ```

4. **Update Collection** (`galaxy.yml` if needed)

---

## 10. Testing and Quality Assurance

### Unit Tests

**Fulfillment Service**:
```bash
cd fulfillment-service
ginkgo run -r
```

**OSAC Operator**:
```bash
cd osac-operator
make test
```

### Integration Tests

**Fulfillment Service** (creates a kind cluster):
```bash
cd fulfillment-service

# Add hosts entries
echo "127.0.0.1 keycloak.keycloak.svc.cluster.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 fulfillment-api.innabox.svc.cluster.local" | sudo tee -a /etc/hosts

# Run integration tests
ginkgo run it

# Keep cluster for debugging
IT_KEEP_KIND=true ginkgo run it
```

### End-to-End Tests

The `osac-test-infra` repository provides E2E testing:

```bash
cd osac-test-infra

# Test hub creation
ansible-playbook playbooks/test_hub_creation.yml \
  -e test_hub_id=my-test-hub \
  -e test_namespace=foobar

# Test ComputeInstance creation
ansible-playbook playbooks/test_compute_instance_creation.yml \
  -e test_compute_instance_id=my-test-ci \
  -e test_namespace=foobar
```

### Linting and Code Quality

```bash
# Ansible projects
pre-commit run --all-files

# Go projects
golangci-lint run

# TypeScript
npm run lint
```

---

## 11. Deployment and Operations

### Prerequisites for Deployment

| Component | Requirement |
|-----------|-------------|
| **Platform** | OpenShift 4.17+ with cluster admin |
| **RHACM** | Red Hat Advanced Cluster Management 2.18+ |
| **OCP-Virt** | OpenShift Virtualization 4.17+ (for VMs) |
| **AAP** | Ansible Automation Platform 2.5+ |
| **Storage** | Dynamic storage class available |
| **Network** | Ingress routes for APIs |

### Deployment Steps

1. **Prepare Prerequisites**:
   ```bash
   cd osac-installer
   oc apply -f prerequisites/
   ```

2. **Create Your Overlay**:
   ```bash
   cp -r overlays/development overlays/myenv
   # Edit overlays/myenv/kustomization.yaml
   # Edit overlays/myenv/prefixTransformer.yaml
   # Add license.zip to overlays/myenv/files/
   ```

3. **Deploy**:
   ```bash
   oc apply -k overlays/myenv
   watch oc get pods -n myenv
   ```

4. **Register Hub**:
   ```bash
   ./scripts/create-hub-access-kubeconfig.sh
   fulfillment-cli login --address <route-url> --token-script "oc create token..."
   fulfillment-cli create hub --kubeconfig=kubeconfig.hub --id my-hub --namespace myenv
   ```

### Monitoring Deployed Components

```bash
# Check all pods
oc get pods -n <namespace>

# Check fulfillment service logs
oc logs -n <namespace> deployment/fulfillment-service -c server --tail=100

# Check operator logs
oc logs -n <namespace> deployment/<prefix>-controller-manager --tail=100

# Check AAP jobs
# Access AAP UI via route
oc get route -n <namespace> | grep aap
```

---

## 12. Contributing to OSAC

### Contribution Workflow

1. **Find or Create an Issue** at https://github.com/osac-project/issues
2. **Get Feedback** from project stakeholders before starting
3. **Fork the Repository** you want to contribute to
4. **Create a Feature Branch** with a descriptive name
5. **Make Changes** following code standards
6. **Run Tests and Linters**
7. **Submit Pull Request** linking the issue
8. **Respond to Review Comments**
9. **Get Merged!**

### Pull Request Guidelines

- **Title**: Clear, concise summary of the change
- **Description**: Explain the why, not just the what
- **Link Issue**: Reference the related issue
- **Tests**: Include tests for new functionality
- **Documentation**: Update docs if behavior changes

### Code Review Expectations

- All PRs require at least one approval
- CI checks must pass
- Address all reviewer feedback
- Keep PRs focused and reasonably sized

---

## 13. Common Tasks and Recipes

### Deploying a Test Cluster

```bash
# 1. Login to fulfillment service
fulfillment-cli login my-fulfillment-api.apps.cluster.local:443

# 2. List available templates
fulfillment-cli get clustertemplates

# 3. Create cluster
fulfillment-cli create cluster \
  --template ocp_4_17_small \
  --name test-cluster \
  -p pull_secret="$(cat pull-secret.json)" \
  -p ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"

# 4. Monitor progress
watch fulfillment-cli get cluster <id>

# 5. Get kubeconfig when ready
fulfillment-cli get kubeconfig <id> > test-kubeconfig.yaml

# 6. Use the cluster
export KUBECONFIG=test-kubeconfig.yaml
oc get nodes
```

### Creating a VM

```bash
fulfillment-cli create computeinstance \
  --template ocp_virt_vm \
  --name my-vm \
  -p cpu_cores=4 \
  -p memory=8Gi \
  -p disk_size=50Gi

# Check status
fulfillment-cli describe computeinstance <id>
```

### Debugging a Failed Cluster

```bash
# Check ClusterOrder status
oc get clusterorder <name> -o yaml

# Check HostedCluster status
oc get hostedcluster -n <cluster-namespace> -o yaml

# Check AAP job logs
# (Access AAP UI and navigate to Jobs)

# Check operator logs
oc logs deployment/<prefix>-controller-manager -n <namespace> --tail=200
```

### Rebuilding and Redeploying

```bash
# Rebuild fulfillment-service
cd fulfillment-service
podman build -t quay.io/myuser/fulfillment-service:dev .
podman push quay.io/myuser/fulfillment-service:dev

# Update deployment
oc set image deployment/fulfillment-service \
  server=quay.io/myuser/fulfillment-service:dev \
  -n <namespace>
```

---

## 14. Troubleshooting Guide

### Common Issues

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| `ImagePullBackOff` | Invalid registry credentials | Check pull secrets in namespace |
| Certificate errors | cert-manager not ready | Check cert-manager pods and issuer status |
| ClusterOrder stuck in Progressing | AAP job failed | Check AAP job logs in UI |
| Webhook timeout | EDA not running | Check EDA activation pod |
| gRPC connection refused | Service not running | Check fulfillment-service pods |

### Debugging Commands

```bash
# Check certificate status
oc describe certificate -n <namespace>

# Check all events
oc get events -n <namespace> --sort-by=.metadata.creationTimestamp

# Check service endpoints
oc get endpoints -n <namespace>

# Check operator logs
oc logs -n <namespace> deployment/<prefix>-controller-manager --tail=500

# Check AAP activation
oc logs -n <namespace> deployment/<prefix>-eda-activation --tail=500

# Check fulfillment service
oc logs -n <namespace> deployment/fulfillment-service -c server --tail=500
```

### AAP Job Debugging

1. Access AAP UI via route
2. Navigate to Jobs
3. Find the failed job
4. Review output and events
5. Check if resources exist in expected state

---

## 15. Additional Resources

### Documentation

- **Architecture**: `docs/architecture/README.md`
- **Cluster Fulfillment**: `docs/architecture/cluster-fulfillment.md`
- **Personas**: `docs/personas.md`
- **Design Doc**: `docs/designdoc.md`

### External References

- [HyperShift Documentation](https://hypershift-docs.netlify.app/)
- [RHACM Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)
- [Ansible Automation Platform](https://www.redhat.com/en/technologies/management/ansible)
- [Event Driven Ansible](https://www.ansible.com/use-cases/event-driven-automation)
- [Kubebuilder Documentation](https://book.kubebuilder.io/)
- [PatternFly](https://www.patternfly.org/)

### Getting Help

- **Issues**: https://github.com/osac-project/issues
- **Documentation**: https://github.com/osac-project/docs
- **Enhancement Proposals**: https://github.com/osac-project/enhancement-proposals

---

## Summary

Congratulations on completing the OSAC onboarding training! Here's what you've learned:

1. **OSAC's Purpose**: An open-source solution for sovereign AI clouds with self-service provisioning
2. **Core Architecture**: Fulfillment Service → OSAC Operator → AAP → Templates
3. **Repository Structure**: 21 repositories organized by function
4. **Key Technologies**: Go, Ansible, Kubernetes Operators, gRPC, React
5. **Workflow**: How requests flow from user to provisioned infrastructure
6. **Templates**: The Ansible-based mechanism for customizable automation
7. **Development**: How to set up your environment and contribute
8. **Operations**: How to deploy and troubleshoot OSAC

### Next Steps

1. **Clone the repositories** and explore the code
2. **Set up a development environment** for one component
3. **Deploy OSAC** to a test cluster if available
4. **Create a test cluster** using the CLI
5. **Find a "good first issue"** and make your first contribution

Welcome to the OSAC community!
