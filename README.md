# Secure Kubernetes delivery platform

Privileged pods, root pods, host access, open storage, committed credentials, unpinned Actions, vulnerable dependencies, and unsigned images from this repo are rejected with a test that can be re-run. The secure path still deploys. Exceptions expire.

This is a lab catalog, not a production landing zone. There is no EKS cluster, no GuardDuty, no Falco, and no agent. The signature check does not prove a Dockerfile was benign. See [the threat model](docs/threat-model.md) for the rest of what this cut leaves out.

Kyverno 1.20 no longer enforces `ClusterPolicy`. The admission rules are `ValidatingPolicy` and `ImageValidatingPolicy`.

## Run

Offline proof, no cluster:

```bash
make prove
```

`make prove` installs pinned tools into `.tools/` on first run. That needs network access. After that:

```bash
make kind-up
make prove-live
make kind-down
```

`make kind-up` creates a one-node [kind](https://kind.sigs.k8s.io/) cluster with Calico, because kindnet does not enforce NetworkPolicy, and installs Kyverno 1.20.0. The command list and the output to expect are in [docs/demo.md](docs/demo.md).

Tools used by the proof: `kubectl`, `kind`, `kyverno`, `helm`, plus Gitleaks, Semgrep, Checkov, and Trivy installed by the Makefile.

## Catalog

| Id | Threat | Proof |
| --- | --- | --- |
| `K01-privileged` | Privileged container | `kyverno test tests/kyverno/disallow-privileged` |
| `K01-non-root` | Container running as root | `kyverno test tests/kyverno/require-non-root` |
| `K01-host-access` | hostPath or host namespaces | `kyverno test tests/kyverno/disallow-host-access` |
| `K01-exception-expiry` | An exception with no end date | `python3 scripts/check_exceptions.py policies/exceptions` |
| `CICD-SEC-6-gitleaks` | Access key in git | `python3 scripts/run_scanners.py` |
| `CICD-SEC-6-semgrep` | Password literal in source | `python3 scripts/run_scanners.py` |
| `misconfig-public-storage` | Storage open to the world | `python3 scripts/run_scanners.py` |
| `K05-default-deny` | Any pod can connect to any pod | `make prove-live` |
| `CICD-SEC-4-action-pins` | Action tag instead of a commit | `python3 scripts/check_action_pins.py .github/workflows` |
| `supply-chain-trivy` | Known vulnerable dependency | `python3 scripts/run_scanners.py` |
| `CICD-SEC-9-signature` | Image tag this repo did not build | `.github/workflows/release.yml` |

The source of the table is [catalog/controls.yaml](catalog/controls.yaml). Each row there has the residual risk and the operability note. A row that is not executable is not listed.

## Operability

- [Failure policy](docs/adr/0001-failure-policy.md): deny when evaluation fails. `kube-system` and `kyverno` are the only namespace exclusions.
- [Webhook down](docs/runbooks/webhook-down.md): how to tell a timeout from a policy denial, and how to prove a deleted webhook did not stay deleted.
- Exceptions live in [policies/exceptions](policies/exceptions). `CODEOWNERS` requires review. `reason`, `owner`, `ticket`, and `expires` are required. An expired file fails `make prove`.

## What a signature does not prove

`CICD-SEC-9-signature` admits `ghcr.io/joao1111/secure-k8s-delivery-platform` only when Cosign keyless verification shows `.github/workflows/release.yml` on `main` signed that digest. There is no Cosign private key in this repo. A compromised workflow can still sign a bad image. The nginx and curl fixtures are outside that policy.
