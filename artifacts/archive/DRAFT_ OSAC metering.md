# Summary and User Stories

# DRAFT: Add metering to OSAC

*This document is not yet a complete enhancement proposal, but for now focuses on getting the user stories right.*

## Summary

This document proposes the addition of a metering system to OSAC. It enables out-of-the-box metering of the core \*aaS offerings, while also enabling the cloud providers that run OSAC to meter the consumption of their custom and value-add services. The solution provides metrics that can be used as input to a revenue model for billing and a quota model for enforcement.

*Add details of the solution here.*

## Motivation

OSAC is a platform that can be used to create a cloud that offers multi-tenant self-service provisioning of various offerings, including VMs, OpenShift clusters, bare metal servers, Model-aaS, etc. Cloud providers running OSAC need to track the usage of those services and attribute the usage back to the users and organizations that are customers of their cloud.

### User Stories

**As a CSP offering \*aaS, I want to consume metering information from my cloud platform that reflects current and past consumption of resources, grouped by tenant (and possibly users or teams within that tenant), so that I can apply my revenue model to generate bills.**

* The CSP will be responsible for revenue and billing. OSAC needs to supply the metering data to be used as input.

**As a CSP offering \*aaS, I want to consume metering information from my cloud platform that reflects current and past consumption of resources, grouped by tenant (and possibly users or teams within that tenant), so that I can apply quota restrictions.**

* OSAC’s metering data will be an input to a quota enforcement system.

#### Core OSAC Services

**As a CSP offering VMaaS, I want to measure consumption by time and instance type.**

* Instance types should be defineable by the CSP based on how they slice up hardware.  
* An instance type might include one or more GPUs, or value-add software. To the metering system, it’s just an instance type.

**As a CSP offering Bare Metal Server \-aaS, I want to measure consumption by time and instance type.**

* Instance types should be defineable by the CSP based on what hardware they choose to offer.  
* An instance type might include one or more GPUs, or value-add software. To the metering system, it’s just an instance type.

**As a CSP offering bare metal Cluster-aaS, I want to measure consumption by time and instance type for each node, plus time for the hosted control plane.**

* Additional resources, such as those associated with storage and networking, would be additional.  
* Pricing could look like $PRICE\_A/minute for a control plane, and $PRICE\_B/minute for each worker node. $PRICE\_B would depend on the instance type of the worker node.

**As a CSP offering Public IP Address \-aaS, I want to measure consumption by time.**

* An IP Address would be metered individually, but reported as a part of some other offering (like a cluster, load balancer, VPN endpoint, …)

**As a CSP offering DBaaS, I want to measure consumption by time and instance type, plus time and GB of data stored.**

* DBaaS instance types are typically defined by cores and memory.  
* Example: a database of $X instance type has been running for $T time. During that time an average of $D GB data was stored.

**As a CSP offering MaaS, I want to measure consumption by number of tokens.**

**As a CSP offering VPNaaS, I want to measure consumption by time the VPN is available, plus time of each user connection.**

* Example: A VPN endpoint was available and attached to an internal network for $T time. During that time, $X connection-seconds were observed.  
* A “connection-second” is incurred when one VPN user is connected to the VPN for one second. 1 connection for 10 seconds or 10 connections for 1 second would each incur 10 connection-seconds.  
* This enables a VPN to be priced as $PRICE\_A/second for the VPN and $PRICE\_B/second for each user connection.

**As a CSP offering DNSaaS, I want to measure consumption by time and zone, plus queries.**

* Example: $X zones were served for $T time. During that time, $Y queries were served against those zones.  
* This enables a zone to be priced as $PRICE\_A/second plus $PRICE\_B/queries.

**As a CSP offering block or filesystem storage \-aaS, I want to measure consumption by time, allocated size, and tier.**

* Example: a $D GB volume for $T time using the $T tier.  
* This enables storage tiers (faster/slower, more/less redundant, etc) to be priced differently.  
* A volume is allocated up-front (ex: 10TB) using a given tier and then measured for how long the user has it.

**As a CSP offering object storage, I want to measure consumption by GB-hours, plus read operations, plus write operations.**

* That way I can apply a pricing model that could be $PRICE\_A/hour for each GB of data stored, plus $PRICE\_B/read operation and $PRICE\_C/write operation.

#### Custom Services

**As a CSP Service Developer creating in-house services such as DBaaS, MaaS, or other SaaS, I want to emit events or make API calls to a metering system that can track consumption of my service.**

#### Tenant Stories

**As a CSP customer, I want to see my usage metrics over a period of time.**

**As a CSP customer, I want to see a consumption view of what I have deployed right now.**

* There are APIs to list and manage resources, but this is a read-only view that can span multiple users or teams within a tenant and that shows all of the resources that are being consumed. An example of a difference would be: an OpenShift cluster may get deployed as one resource, but it would incur usage across many billable resources including a control plane, VMs, storage, DNS, etc. This consumption view would show the latter.

### Goals

* Enable Tenant Users to see how much usage they have incurred and are incurring right now.  
* Enable Tenant Admins to see how much usage their users have incurred and are incurring right now.  
* Enable CSPs to apply billing and quota models.  
* Enable specific resources to be nested. For example, a VM has its usage measured directly, but it is also part of an OpenShift cluster. The VM would be a child resource of the cluster.

### Non-Goals

* Add billing or payment features.  
* Add a quota system (that will be done separately).

# Tab 2

## Proposal

This enhancement proposes adopting [OpenMeter](https://openmeter.io) as the core usage metering and aggregation system for OSAC. OpenMeter is an open-source platform designed to collect usage events, aggregate them into defined metrics, and provide a queryable API for consumption data. This system will serve as the single source of truth for all resource consumption, directly enabling CSPs to meet their requirements for applying revenue models, generating bills, and enforcing quotas.

The proposed changes are enumerated as follows:

1. **OpenMeter Deployment and Integration:** Deploy the core OpenMeter components (Ingestion Gateway, Storage/Aggregation layer, and Query API) into the OSAC management cluster. This establishes the necessary infrastructure to handle high-volume event ingestion and low-latency aggregation.  
2. **Core Service Instrumentation:** Modify the controllers for all core OSAC `*aaS` offerings (e.g., VMaaS, Cluster-aaS, DBaaS, Storage-aaS) to emit granular usage events to the OpenMeter Ingestion Gateway. These events, known as "tracks," will contain all necessary metadata for grouping, including `tenant_id`, `user_id`, `resource_id`, and `parent_resource_id`.  
3. **Custom Metering via CRD:** Introduce a new Custom Resource Definition (CRD), `MeterDefinition`, which allows CSPs to define how raw events from *both* core OSAC services and custom services are transformed into billable metrics (e.g., aggregating time, counting operations, or summing tokens).  
4. **Usage Consumption APIs:** Expose the aggregated usage data via a secure, read-only OSAC API. This wrapper API will serve two primary purposes:  
   * Provide bulk, aggregated data to the CSP's external billing and quota systems.  
   * Provide a tenant-scoped consumption view for Tenant Users and Admins to see current and historical usage.

The choice of OpenMeter is driven by its focus on billing-grade accuracy, its ability to handle complex metric definitions (essential for services like VPNaaS and Object Storage), and its extensibility, which allows CSP Service Developers to easily instrument their custom services.

### Workflow Description

This workflow details the process of consuming and viewing metered usage, using a bare metal Cluster-aaS deployment as an example, which involves nested resources.

**Actors:**

* **Cluster Creator/Tenant User:** A customer who deploys an OSAC resource.  
* **OSAC Controllers:** The control plane components responsible for provisioning resources (e.g., Cluster-aaS controller, VMaaS controller for worker nodes).  
* **OpenMeter Ingestion Gateway:** The endpoint that receives consumption events.  
* **CSP Billing System:** The external system that generates bills.  
* **Tenant Usage API:** The interface for customers to view their consumption.

**Starting State:** The OSAC platform is installed with the OpenMeter metering system. The CSP has configured the necessary `MeterDefinition` CRDs to track cluster time, node time, and networking usage.

1. **Cluster Creator** requests the deployment of a Cluster-aaS resource, which includes one hosted control plane and three worker nodes of instance type `bare-metal-X`.  
2. **OSAC Controllers** provision the cluster components. As each component becomes active:  
   * The **Cluster Controller** emits a `cluster_control_plane_time` event, tagged with the `tenant_id` and the cluster’s `resource_id`.  
   * The **VMaaS Controller** (or equivalent bare metal controller) emits a `bare_metal_node_time` event for each worker node, tagged with the `tenant_id`, the node’s `resource_id`, its `instance_type`, and crucially, the cluster’s `parent_resource_id`.  
3. The **OpenMeter Ingestion Gateway** receives these events and aggregates them according to the `MeterDefinition` into two primary metrics: `control_plane_minutes` and `worker_node_minutes` (grouped by instance type).  
4. The **CSP Billing System** queries the OpenMeter Query API at the end of the billing cycle, requesting the total aggregated usage data grouped by `tenant_id`. This data is used as input for the CSP's revenue model.  
5. The **Cluster Creator** uses the **Tenant Usage API** to see their current consumption view. The API queries OpenMeter, aggregates the control plane and worker node usage, and presents the consumption view as a single “Cluster Usage” metric, showing the total minutes consumed for the cluster and its nested components.

API Extensions

This enhancement introduces new Kubernetes API surface area:

* **`MeterDefinition` (New CRD):** This Cluster-scoped CRD defines the logic for how raw usage events are aggregated. It includes fields for the source event stream, aggregation function (`sum`, `gauge`, `count`), resolution interval, and the grouping keys (e.g., `tenant_id`, `instance_type`).  
* **`TenantUsage` (New Read-Only API/CRD):** This Namespaced resource provides a historical and current read-only view of aggregated usage for a specific tenant. Access will be strictly controlled via RBAC to ensure Tenant Users/Admins can only view data scoped to their `tenant_id`.  
* **Augmentation of Existing Resource CRDs:** Core resource CRDs (e.g., VM, Cluster) will be required to carry standardized metadata labels or annotations that define the `tenant_id` and `parent_resource_id`. This modification ensures OSAC controllers can correctly attribute all emitted usage events.

Implementation Details/Notes/Constraints

* **Standardized Event Schema:** To support all user stories, including nesting and grouping by instance type, every usage event emitted by an OSAC controller must adhere to a minimal standard schema. At a minimum, this includes: `metric_name` (e.g., `vmaas_time`, `dns_queries`), `value` (the quantity of usage), `time` (timestamp), `tenant_id`, `resource_id`, and optional `parent_resource_id`.  
* **Data Retention:** Raw event data (tracks) will be retained for a short period (e.g., 7 days) for debugging purposes. Aggregated metering data, which is critical for billing and historical tenant views, must be persisted in long-term storage (e.g., object storage or a durable database) for a minimum of 13 months for audit and dispute resolution purposes.  
* **CSP-Defined Instance Types:** The metering system will rely entirely on the `instance_type` metadata provided in the usage event for services like VMaaS and Bare Metal Server-aaS. The metering system is agnostic to the definition of the instance type; it only uses the provided string for grouping.  
* **Handling Complex Metrics:** The `MeterDefinition` must be flexible enough to handle burst/discrete metrics (like DNS queries or MaaS tokens) and continuous metrics (like time and allocated size). The configuration will define how to transform the continuous start/stop events into aggregated duration metrics.

Risks and Mitigations

| Risk | Mitigation |
| ----- | ----- |
| **Data Loss for Billing**: Failure in a service controller or the Ingestion Gateway results in lost metering events, leading to inaccurate billing and revenue loss. | Implement a robust, persistent message queue (e.g., Kafka or similar high-throughput streaming platform) between OSAC controllers and the OpenMeter Ingestion Gateway to handle backpressure and guarantee delivery. Controllers must persist events locally before sending. |
| **Performance Bottleneck:** High event volume from large-scale OSAC deployments overwhelms the OpenMeter ingestion or aggregation components. | Deploy OpenMeter as a horizontally scalable, distributed service cluster. Utilize performance testing to establish documented capacity limits. Controllers must implement event batching to minimize API calls. |
| **Security and Access Control:** Metering data is highly sensitive for both CSPs and customers. | Enforce strict RBAC on the Query API, ensuring cross-tenant data visibility is only available to authenticated CSP administrators. Implement end-to-end encryption for all metering data in transit and at rest. |
| **Operational Complexity:** Introducing a new critical, stateful, and highly available system (OpenMeter) adds complexity to OSAC operations. | Provide comprehensive installation, monitoring, and runbook documentation for OpenMeter. Integrate OpenMeter status into OSAC’s overall health dashboard. |

Drawbacks

The idea is to find the best form of an argument why this enhancement should *not* be implemented.

* **New Critical Dependency and Operational Burden:** Implementing OpenMeter introduces a new, highly critical component into the OSAC platform. This system must be maintained with 99.99%+ availability and data integrity, adding significant operational complexity and overhead compared to leveraging existing monitoring infrastructure.  
* **Increased Complexity for Developers:** While providing a solution for custom services, this enhancement requires all existing and future OSAC service developers to learn and integrate with a new event-emitting API and a new configuration model (`MeterDefinition`), increasing the development and maintenance burden across all `*aaS` teams.  
* **Resource Overhead:** The OpenMeter platform requires dedicated compute and storage resources to handle the high volume of incoming events, which may increase the minimum resource footprint required for an OSAC deployment.  
* **Vendor Lock-in Risk:** While OpenMeter is open-source, adopting it deeply integrates the OSAC control plane with its specific event schema and data model. Should OpenMeter be superseded, replacing the core metering system would require significant refactoring of every OSAC `*aaS` controller.

