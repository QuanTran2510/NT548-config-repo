# config-repo

Single source of truth for what runs on the cluster. ArgoCD watches **only** this repo.

| Path | Owner | Content |
|---|---|---|
| `charts/service/` | platform engineer | Golden-path Helm chart shared by all services (non-root, resource limits, pinned image tag enforced) |
| `apps/<service>/values.yaml` | CI / developer | image repository + tag, container port |
| `envs/<service>-<site>/values.yaml` | **placement optimiser** (generated) | `replicaCount`, `nodeSelector.region` |
| `argocd/applicationset.yaml` | platform engineer | one ArgoCD Application per `envs/*/values.yaml` |

Never edit `envs/` by hand: `python export_placement.py --config-repo . --solver ilp --commit` (run from app-repo) rewrites it.

## How a change reaches a pod
1. optimiser commits `envs/web-api-ap-southeast/values.yaml` (replicaCount 1 -> 3)
2. ArgoCD ApplicationSet sees the changed file, renders `charts/service` with
   `apps/web-api/values.yaml` + `envs/web-api-ap-southeast/values.yaml`
3. Deployment is scaled; scheduler places pods on nodes labelled `region=ap-southeast`

Rollback = `git revert <commit>`.

## Before first use
- Replace `YOUR_USER` in `argocd/applicationset.yaml` (2 places) with your GitHub path.
- `apps/*/values.yaml` use a placeholder non-root nginx image; CI (Week 4) replaces repository and tag.
- Nodes must carry the `region` label (Ansible, Week 3).

## Local check (needs helm)
    helm template web-api-us-east charts/service \
      -f apps/web-api/values.yaml -f envs/web-api-us-east/values.yaml
