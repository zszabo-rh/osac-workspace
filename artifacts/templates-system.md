# OSAC Templates System

Templates are Ansible Roles that define how infrastructure gets provisioned.

## Template Structure

```
roles/my_template/
├── tasks/
│   ├── install.yaml       # Create/update infrastructure
│   ├── postinstall.yaml   # Post-creation configuration
│   └── delete.yaml        # Remove infrastructure
├── defaults/
│   └── main.yaml          # Default parameter values
└── meta/
    ├── cloudkit.yaml      # OSAC-specific metadata
    └── argument_specs.yaml # Parameter definitions
```

## Template Metadata (`meta/cloudkit.yaml`)

```yaml
title: "OpenShift 4.17 small"
description: "OpenShift 4.17 with small instances as worker nodes"
template_type: cluster  # or 'vm'
default_node_request:
  - resourceClass: fc430
    numberOfNodes: 2
```

## Available Templates

| Template | Type | Description |
|----------|------|-------------|
| `ocp_4_17_small` | Cluster | Minimal OpenShift 4.17 cluster |
| `ocp_4_17_small_github` | Cluster | OpenShift 4.17 with GitHub OAuth |
| `ocp_virt_vm` | VM | Configurable virtual machine |
