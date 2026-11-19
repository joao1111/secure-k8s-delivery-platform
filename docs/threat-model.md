# Threat model

The system under discussion is this repository and the `kind` cluster `make kind-up` builds. It is a lab, not a production account.

## Boundaries

| Boundary | Who is trusted | What crosses it |
| --- | --- | --- |
| Laptop | The person running `make` | Source, fixtures, and the tools in `.tools/` |
| GitHub Actions | The `main` branch workflows in this repo | Image build, Trivy, SBOM, Cosign identity |
| GHCR | The digest signed by `release.yml` | The image and its signature |
| Cluster | Kyverno, Calico, and the kubelet | Admission decisions and pod traffic |

A pull request can change files. It cannot sign an image. The signature subject is `.github/workflows/release.yml` on `main`.

## What each control is for

| Threat | Catalog id |
| --- | --- |
| Privileged container | `K01-privileged` |
| Root container | `K01-non-root` |
| hostPath or host namespaces | `K01-host-access` |
| An exception with no end date | `K01-exception-expiry` |
| An access key in git | `CICD-SEC-6-gitleaks` |
| A password literal in source | `CICD-SEC-6-semgrep` |
| Storage left open to the world | `misconfig-public-storage` |
| Any pod connecting to any pod | `K05-default-deny` |
| An action that moves under a tag | `CICD-SEC-4-action-pins` |
| A known vulnerable dependency | `supply-chain-trivy` |
| An image tag this repo did not build | `CICD-SEC-9-signature` |

## Accepted for this cut

- No AWS account, GuardDuty, KMS, or Access Analyzer.
- No Falco, so runtime behavior after admission is not detected.
- No IRSA. The GitHub Actions identity is the workload identity that is actually tested, and only in the release workflow.
- The nginx and curl images are not signed by this repo. The signature policy does not look at them.
- Default-deny does not include a DNS allow. The live check uses the pod IP.
- NetworkPolicy is enforced because Calico is installed. kindnet would ignore it.
