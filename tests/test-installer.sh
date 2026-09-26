#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=install.sh
source "$ROOT_DIR/install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  [[ "$actual" == "$expected" ]] || fail "$message: expected '$expected', got '$actual'"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

assert_eq "1.2.11" "$RELEASE_VERSION" "release pin"
assert_eq "e1d4ca363d00e0a1c51e94ae38802f75c13ddddcb4e6afb09c49d04a50c36757" "$RELEASE_SHA256" "release digest"

printf 'termux-agy-arm64\n' >"$tmp/payload"
digest=$(sha256sum "$tmp/payload" | awk '{print $1}')
verify_sha256 "$tmp/payload" "$digest"

if (verify_sha256 "$tmp/payload" "0000000000000000000000000000000000000000000000000000000000000000" >/dev/null 2>&1); then
  fail "verify_sha256 accepted a bad digest"
fi

cat >"$tmp/cpu-lse" <<'EOF'
Features : fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics
EOF
AGY_CPUINFO_PATH="$tmp/cpu-lse" cpu_has_lse || fail "cpu_has_lse missed atomics"

cat >"$tmp/cpu-no-lse" <<'EOF'
Features : fp asimd evtstrm aes pmull sha1 sha2 crc32
EOF
if AGY_CPUINFO_PATH="$tmp/cpu-no-lse" cpu_has_lse; then
  fail "cpu_has_lse reported atomics when absent"
fi

mkdir -p "$tmp/archive-src"
printf '#!/bin/sh\n' >"$tmp/archive-src/agy"
printf 'engine\n' >"$tmp/archive-src/agy.va39"
tar -czf "$tmp/safe.tar.gz" -C "$tmp/archive-src" agy agy.va39
assert_safe_archive "$tmp/safe.tar.gz"

printf 'ok: installer unit checks passed\n'
