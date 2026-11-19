#!/usr/bin/env bash
# Used by the release workflow. Needs DIGEST of an image this repo just signed.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
export PATH="$root/.tools:$root/.tools/venv/bin:$PATH"
: "${DIGEST:?set DIGEST to the signed image digest}"

make kind-up
trap 'make kind-down' EXIT

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  kubectl create secret docker-registry ghcr \
    --namespace kyverno \
    --docker-server=ghcr.io \
    --docker-username="${GHCR_USER:?set GHCR_USER}" \
    --docker-password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

ns=paved-road
kubectl delete namespace "$ns" --ignore-not-found=true --wait=true
kubectl create namespace "$ns"
kubectl apply -f policies/disallow-privileged.yaml
kubectl apply -f policies/require-non-root.yaml
kubectl apply -f policies/disallow-host-access.yaml
kubectl apply -f policies/verify-release-signature.yaml
if kubectl get secret ghcr --namespace kyverno >/dev/null 2>&1; then
  kubectl patch imagevalidatingpolicy verify-release-signature --type=merge \
    -p '{"spec":{"credentials":{"secrets":["ghcr"]}}}'
fi

err=$(mktemp)
for _ in $(seq 1 30); do
  if kubectl apply -f app/fixtures/insecure/unsigned-server.yaml >"$err" 2>&1; then
    sleep 2
    continue
  fi
  if grep -q "must be signed" "$err"; then
    echo "unsigned image denied"
    break
  fi
  sleep 2
done
grep -q "must be signed" "$err"

cat > /tmp/signed-server.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: signed-server
  namespace: paved-road
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: server
      image: ghcr.io/joao1111/secure-k8s-delivery-platform@${DIGEST}
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
        runAsNonRoot: true
        runAsUser: 65532
        capabilities:
          drop: ["ALL"]
EOF
signed_ok=0
for _ in $(seq 1 30); do
  if kubectl apply -f /tmp/signed-server.yaml >"$err" 2>&1; then
    signed_ok=1
    break
  fi
  sleep 2
done
if [[ "$signed_ok" -ne 1 ]]; then
  echo "signed digest was not admitted" >&2
  cat "$err" >&2
  exit 1
fi
rm -f "$err"
echo "signed digest admitted"
