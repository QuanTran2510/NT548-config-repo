# Guardrails (ValidatingAdmissionPolicy)

Five policies, nine rules, enforced by the Kubernetes API server itself (no extra pods, no webhook).
They apply to Pods and Deployments in namespaces labelled `platform/guardrails=enforced`
(realtime-chat, web-api, analytics, placement-optimiser). `monitoring`, `argocd` and `kube-system` are not covered.

| Policy | Blocks |
|---|---|
| guardrail-resource-limits | a container without CPU/memory requests and limits |
| guardrail-image-tag | an image without a tag, or with tag `latest` |
| guardrail-non-root | `runAsUser: 0`, or no `runAsNonRoot: true` |
| guardrail-no-privileged | `privileged: true`, `hostNetwork: true` |
| guardrail-image-registry | images outside ghcr.io/quantran2510/ and docker.io/nginxinc/ |

Defence in depth: the Helm chart already refuses `latest` at render time, but anyone can apply raw YAML; these
policies are the gate that cannot be bypassed.

Rollout: bindings start in `Warn` (violations are reported but allowed). Check with
`tests/guardrails/run.sh existing`, then change `[Warn]` to `[Deny]` in `bindings.yaml` and merge.
Tests: `tests/guardrails/run.sh` (server-side dry run, nothing is created).
