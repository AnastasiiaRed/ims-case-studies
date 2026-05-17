# CI/CD Concept: Lightweight On-Prem Platform for a Monorepo

## Goal
Build an open-source, on-prem CI/CD platform for one monolithic repository. The system runs on existing CPU/GPU Kubernetes nodes and storage, and must be maintainable by two employees.

## Process Overview

```mermaid
flowchart TB
  subgraph CI["CI flow"]
    Dev["Developer"]
    Gitea["Gitea<br/>monorepo"]
    Woodpecker["Woodpecker CI"]
    K8s["Kubernetes<br/>CPU/GPU nodes"]
    MinIO["S3-compatible object storage<br/>(MinIO / RustFS / existing storage)"]
    Loki["Loki"]
    Prometheus["Prometheus"]
    Grafana["Grafana"]

    Dev -->|"push / PR"| Gitea
    Gitea -->|"webhook"| Woodpecker
    Woodpecker -->|"schedules job pods"| K8s
    K8s -->|"artifacts, caches, reports"| MinIO
    K8s -.->|"logs via FluentBit"| Loki
    K8s -.->|"metrics scraped"| Prometheus
    Loki --> Grafana
    Prometheus --> Grafana
  end

  subgraph Platform["Platform management"]
    GitOps["Platform manifests<br/>in Git"]
    Argo["Argo CD"]

    GitOps -->|"watch"| Argo
  end

  Argo -->|"reconcile desired state"| K8s
```

## Main motivation

When comparing various existing solutions, the main motivations were simplicity (since there is only 2 employees), no vendor-lock so that each component can be replaced individually (for example, Gitea has built-in Actions, but this would couple CI system to Gitea, so no real portability), open-source solutions.

## Component Choices
| Area | Tool | Why | Limitations | Alternatives |
|------|------|-----|-------------|--------------|
| Git hosting | Gitea | Lightweight self-hosted Git. Monorepo hosting, PRs, webhooks, Git LFS, CODEOWNERS, simple administration. | No GitHub App equivalent — only long-lived PATs and deploy keys. |  |
| CI orchestrator | Woodpecker CI | Simple hosting. Single server + agents. Steps run as pods — GPU/CPU scheduling via Kubernetes. Path filters for monorepo. | Small community, not industry standard. No reusable pipeline primitives. No matrix builds. | Tekton would be preferable if employees have good k8s knowledge - because all Tekton resources are CRDs in Kubernetes, so purely GitOps approach + some more complex CI stuff like matrix.  |
| Resource management | k3s | Kubernetes CPU/GPU scheduling, requests/limits, quotas, taints/tolerations, node selectors, namespaces. Low ops weight. | SQLite default datastore not suitable for HA. Suitable more for small clusters. Less hardened than RKE2. | RKE2 |
| CD orchestrator | Argo CD | GitOps deployment, drift detection, rollback via Git revert. Manual sync approvals. Easy platform updates. | Kubernetes-only. Resource-heavy on large clusters. |  |
| Artifacts | MinIO | S3-compatible, universal tooling support. No pre-allocation. Multiple concurrent writers. Lifecycle policies. | AGPLv3 license. | RustFS - new competitor after license changed in MinIO (MinIO changed its license to AGPLv3 — not an issue for internal use, but worth noting for commercials). |
| Monitoring | Prometheus + Grafana | Standard Kubernetes monitoring. Platform health, GPU/CPU usage. Easy Helm install, huge community. | Short-term retention by default. Prometheus doesn't scale horizontally easily without extra tooling. | |
| Logging | Loki + FluentBit + Grafana | FluentBit fetches stdout logs without code changes. Same Grafana UI for logs,alerts and metrics.  | Complex regex queries are slow. Loki community support growing, but hard to find good examples/doc on syntax. queries. |   |

## Deployment and Update Process
All platform components are installed with Kustomize/Helm and reconciled by Argo CD. Desired state lives in Git, either in a separate platform repository or a protected platform area of the monorepo.

Example update: change the Woodpecker Helm chart or image version in Git, merge after review, sync with Argo CD, run a test pipeline that builds an image and uploads a generic artifact. Rollback is done by reverting the Git change.

## Benefits and Weaknesses
Benefits: small understandable stack, simple developer experience, Kubernetes-native execution, CPU/GPU resource control, monorepo-aware builds, GitOps-based updates.

Weaknesses: Woodpecker is less industry-standard than Tekton, Nx requires repository discipline, and the modular stack needs integration work. Some components might not be yet industry standards, like RustFS is promising but should be validated before replacing a mature S3-compatible store.
Some components like k3s, ArgoCD, Gitea need to be preinstalled on cluster before using GitOps approach. Bootstrapping can be done by e.g. main cluster orchestrator/one-time setup with using Infra-As-Code and Config-As-Code tools e.g. pulumi, ansible etc.

## Maintainability, Security and Long-Term Support

**Maintainability.** Each component can be upgraded easily (binary or helm chart/kustomize). State lives in three places: Gitea (repositories + metadata), MinIO (artifacts), etcd (cluster state). Backups target those three. Updates follow the same flow for every component: bump version in Git, review, merge, Argo CD syncs. Components can be replaced without changing the full architecture: Woodpecker -> Tekton, MinIO -> RustFS, k3s -> RKE2.

**Security.** Based on least privilege throughout:
- CI pods run in isolated namespaces with restricted service accounts — no access to the control plane
- Argo CD uses pull-based GitOps —  (no need to log in to cluster from pipeline with kubeconfig etc)
- OIDC from Gitea as single sign-on — one account per person across all tools, one place to revoke access
- Platform changes are Git PRs with following GitOps
- RBAC policies (e.g. MinIO, ArgoCD)
- GPU/CPU nodes are tainted so only authorized workloads land on them

**Long-term support.** All components are actively maintained OSS with clear migration paths if needed. Platform state lives in Git — a new team member can understand the full setup from one repo. No vendor lock-in: each component can be swapped independently.