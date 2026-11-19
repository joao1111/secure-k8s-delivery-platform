#!/usr/bin/env bash
# Install pinned CLI tools into .tools/. Re-running is a no-op when the binaries exist.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tools="$root/.tools"
mkdir -p "$tools"

case "$(uname -m)" in
  x86_64)
    kyverno_arch=x86_64
    go_arch=amd64
    gitleaks_arch=x64
    trivy_arch=64bit
    ;;
  aarch64 | arm64)
    kyverno_arch=arm64
    go_arch=arm64
    gitleaks_arch=arm64
    trivy_arch=ARM64
    ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

fetch_tar() {
  local dest=$1
  local url=$2
  local bin_name=$3
  if [[ -x "$dest" ]]; then
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  curl -fsSL "$url" -o "$tmp/archive.tar.gz"
  tar -C "$tmp" -xzf "$tmp/archive.tar.gz"
  local bin
  bin=$(find "$tmp" -type f -name "$bin_name" | head -n 1)
  install -m 0755 "$bin" "$dest"
  rm -rf "$tmp"
}

if [[ ! -x "$tools/kyverno" ]]; then
  fetch_tar "$tools/kyverno" \
    "https://github.com/kyverno/kyverno/releases/download/v1.20.0/kyverno-cli_v1.20.0_linux_${kyverno_arch}.tar.gz" \
    kyverno
fi

if [[ ! -x "$tools/kind" ]]; then
  curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-${go_arch}" -o "$tools/kind"
  chmod 0755 "$tools/kind"
fi

if [[ ! -x "$tools/kubectl" ]]; then
  curl -fsSL "https://dl.k8s.io/release/v1.37.2/bin/linux/${go_arch}/kubectl" -o "$tools/kubectl"
  chmod 0755 "$tools/kubectl"
fi

if [[ ! -x "$tools/helm" ]]; then
  fetch_tar "$tools/helm" \
    "https://get.helm.sh/helm-v3.18.4-linux-${go_arch}.tar.gz" \
    helm
fi

fetch_tar "$tools/gitleaks" \
  "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_${gitleaks_arch}.tar.gz" \
  gitleaks

fetch_tar "$tools/trivy" \
  "https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-${trivy_arch}.tar.gz" \
  trivy

if [[ ! -x "$tools/venv/bin/semgrep" ]]; then
  python3 -m venv "$tools/venv"
  "$tools/venv/bin/pip" install --disable-pip-version-check -r "$root/requirements.txt"
fi

echo "tools ready in $tools"
