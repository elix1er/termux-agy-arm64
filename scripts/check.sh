#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

files=(
  install.sh
  scripts/check.sh
  tests/test-installer.sh
)

printf '==> bash syntax\n'
for file in "${files[@]}"; do
  bash -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
  printf '==> shellcheck\n'
  shellcheck -x "${files[@]}"
else
  printf '==> shellcheck (skipped: not installed)\n'
fi

if command -v shfmt >/dev/null 2>&1; then
  printf '==> shfmt\n'
  shfmt -d -i 2 -ci "${files[@]}"
else
  printf '==> shfmt (skipped: not installed)\n'
fi

printf '==> installer tests\n'
./tests/test-installer.sh

printf '==> release pin shape\n'
grep -Eq '^readonly RELEASE_VERSION="[0-9]+\.[0-9]+\.[0-9]+"$' install.sh
grep -Eq '^readonly RELEASE_SHA256="[0-9a-f]{64}"$' install.sh

printf 'ok: all checks passed\n'
