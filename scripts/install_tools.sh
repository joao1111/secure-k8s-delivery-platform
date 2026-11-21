#!/usr/bin/env bash
# Install pinned CLI tools into .tools/. Re-running is a no-op when the binaries exist.
# Download hashes live in scripts/checksums/tools.txt.
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

checksum_for() {
  local name=$1
  local arch=$2
  local sum
  sum=$(awk -v n="$name" -v a="$arch" '$1 == n && $2 == a { print $3; exit }' "$root/scripts/checksums/tools.txt")
  if [[ ! "$sum" =~ ^[0-9a-f]{64}$ ]]; then
    echo "no sha256 for $name $arch in scripts/checksums/tools.txt" >&2
    exit 1
  fi
  printf '%s' "$sum"
}

sha256_check() {
  local file=$1
  local expected=$2
  local actual
  actual=$(sha256sum "$file" | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    echo "checksum mismatch for $file" >&2
    echo "expected $expected" >&2
    echo "actual   $actual" >&2
    exit 1
  fi
}

fetch_tar() {
  local dest=$1
  local url=$2
  local bin_name=$3
  local expected=$4
  if [[ -x "$dest" ]]; then
    return
  fi
  local tmp bin
  tmp=$(mktemp -d)
  curl -fsSL "$url" -o "$tmp/archive.tar.gz"
  sha256_check "$tmp/archive.tar.gz" "$expected"
  tar -C "$tmp" -xzf "$tmp/archive.tar.gz"
  bin=$(find "$tmp" -type f -name "$bin_name" | head -n 1)
  install -m 0755 "$bin" "$dest"
  rm -rf "$tmp"
}

fetch_bin() {
  local dest=$1
  local url=$2
  local expected=$3
  if [[ -x "$dest" ]]; then
    return
  fi
  local tmp
  tmp=$(mktemp)
  curl -fsSL "$url" -o "$tmp"
  sha256_check "$tmp" "$expected"
  install -m 0755 "$tmp" "$dest"
  rm -f "$tmp"
}

fetch_tar "$tools/kyverno" \
  "https://github.com/kyverno/kyverno/releases/download/v1.20.0/kyverno-cli_v1.20.0_linux_${kyverno_arch}.tar.gz" \
  kyverno \
  "$(checksum_for kyverno "$kyverno_arch")"

fetch_bin "$tools/kind" \
  "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-${go_arch}" \
  "$(checksum_for kind "$go_arch")"

fetch_bin "$tools/kubectl" \
  "https://dl.k8s.io/release/v1.37.2/bin/linux/${go_arch}/kubectl" \
  "$(checksum_for kubectl "$go_arch")"

fetch_tar "$tools/helm" \
  "https://get.helm.sh/helm-v3.18.4-linux-${go_arch}.tar.gz" \
  helm \
  "$(checksum_for helm "$go_arch")"

fetch_tar "$tools/gitleaks" \
  "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_${gitleaks_arch}.tar.gz" \
  gitleaks \
  "$(checksum_for gitleaks "$gitleaks_arch")"

fetch_tar "$tools/trivy" \
  "https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-${trivy_arch}.tar.gz" \
  trivy \
  "$(checksum_for trivy "$trivy_arch")"

if [[ ! -x "$tools/venv/bin/semgrep" ]]; then
  python3 -m venv "$tools/venv"
  "$tools/venv/bin/pip" install --disable-pip-version-check --require-hashes -r "$root/requirements.txt"
fi

echo "tools ready in $tools"
