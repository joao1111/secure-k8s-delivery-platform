#!/usr/bin/env bash
# Apply the catalog to the kind cluster and assert deny, allow, exception, and network results.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$root/.tools:$root/.tools/venv/bin:$PATH"
ns=paved-road

if ! kubectl config current-context | grep -q 'kind-secure-delivery'; then
  echo "current context is not kind-secure-delivery; run make kind-up" >&2
  exit 1
fi

kubectl delete namespace "$ns" --ignore-not-found=true --wait=true
kubectl create namespace "$ns"
kubectl apply -f "$root/policies/disallow-privileged.yaml"
kubectl apply -f "$root/policies/require-non-root.yaml"
kubectl apply -f "$root/policies/disallow-host-access.yaml"
kubectl apply -f "$root/policies/verify-release-signature.yaml"

deny() {
  local file=$1
  local needle=$2
  local attempt err
  err=$(mktemp)
  for attempt in $(seq 1 30); do
    if kubectl apply -f "$file" >"$err" 2>&1; then
      sleep 2
      continue
    fi
    if grep -q "$needle" "$err"; then
      rm -f "$err"
      echo "denied $(basename "$file")"
      return 0
    fi
    sleep 2
  done
  echo "expected deny ($needle) for $file" >&2
  cat "$err" >&2
  exit 1
}

kubectl apply -f "$root/app/fixtures/secure/web.yaml"
kubectl wait --namespace "$ns" --for=condition=Ready pod/web --timeout=180s
echo "golden pod Ready"

deny "$root/app/fixtures/insecure/privileged-pod.yaml" "Privileged containers are denied"
deny "$root/app/fixtures/insecure/root-pod.yaml" "Containers must run as non-root"
deny "$root/app/fixtures/insecure/hostpath-pod.yaml" "Host namespaces and hostPath volumes are denied"
deny "$root/app/fixtures/insecure/host-network-pod.yaml" "Host namespaces and hostPath volumes are denied"
deny "$root/app/fixtures/insecure/host-pid-pod.yaml" "Host namespaces and hostPath volumes are denied"
deny "$root/app/fixtures/insecure/host-ipc-pod.yaml" "Host namespaces and hostPath volumes are denied"

kubectl apply -f "$root/policies/exceptions/allow-legacy-root.yaml"
kubectl apply -f "$root/app/fixtures/insecure/legacy-root.yaml"
kubectl get pod legacy-root --namespace "$ns" >/dev/null
echo "labeled root pod admitted by exception"
deny "$root/app/fixtures/insecure/root-pod.yaml" "Containers must run as non-root"

kubectl apply -f "$root/policies/default-deny.yaml"
kubectl apply -f "$root/app/fixtures/secure/client.yaml"
kubectl apply -f "$root/app/fixtures/secure/client-blocked.yaml"
kubectl wait --namespace "$ns" --for=condition=Ready pod/client --timeout=180s
kubectl wait --namespace "$ns" --for=condition=Ready pod/client-blocked --timeout=180s

ip=$(kubectl get pod web --namespace "$ns" -o jsonpath='{.status.podIP}')
kubectl exec --namespace "$ns" client -- curl -sf --max-time 10 "http://${ip}:8080/" >/dev/null
echo "labeled client reached web"
if kubectl exec --namespace "$ns" client-blocked -- curl -sf --max-time 10 "http://${ip}:8080/" >/dev/null; then
  echo "unlabeled client reached web; default deny did not hold" >&2
  exit 1
fi
echo "unlabeled client blocked"
echo "prove-live ok"
