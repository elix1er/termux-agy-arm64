#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

readonly PROJECT="termux-agy-arm64"
readonly RELEASE_REPO="wallentx/antigravity-cli-termux"
readonly RELEASE_VERSION="1.3.5"
readonly RELEASE_ASSET="antigravity-termux-standalone.tar.gz"
readonly RELEASE_SHA256="240c760f0bf5964ad36c0617a6dac9818a3dc070ce99adccb80bf2fb2809300f"
readonly RELEASE_URL="https://github.com/${RELEASE_REPO}/releases/download/v${RELEASE_VERSION}/${RELEASE_ASSET}"

TMP_DIR=""
BACKUP_DIR=""
INSTALL_STARTED=0
INSTALL_OK=0
HAD_AGY=0
HAD_ENGINE=0
HAD_LEGACY_PACKAGE=0
LEGACY_PACKAGE_PATH=""

if [[ -t 1 ]]; then
  readonly BOLD=$'\033[1m'
  readonly DIM=$'\033[2m'
  readonly GREEN=$'\033[32m'
  readonly RED=$'\033[31m'
  readonly CYAN=$'\033[36m'
  readonly RESET=$'\033[0m'
else
  readonly BOLD=""
  readonly DIM=""
  readonly GREEN=""
  readonly RED=""
  readonly CYAN=""
  readonly RESET=""
fi

info() { printf '%b\n' "${CYAN}::${RESET} $*"; }
ok() { printf '%b\n' "${GREEN}ok${RESET} $*"; }
warn() { printf '%b\n' "${DIM}warn${RESET} $*" >&2; }
die() {
  printf '%b\n' "${RED}error${RESET} $*" >&2
  exit 1
}

usage() {
  cat <<EOF
${PROJECT} installer

Usage:
  ./install.sh
  ./install.sh --check
  ./install.sh --help

--check  Validate the host and print the pinned release without changing anything.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_termux() {
  [[ "$(uname -m)" == "aarch64" ]] || die "This installer only supports aarch64."
  [[ -n "${PREFIX:-}" ]] || die "PREFIX is not set. Run this inside native Termux."
  command -v pkg >/dev/null 2>&1 || die "Termux package manager 'pkg' was not found."
  case "$PREFIX" in
    /data/data/*/files/usr) ;;
    *) die "PREFIX does not look like a native Termux prefix: $PREFIX" ;;
  esac
}

cpu_has_lse() {
  local cpuinfo="${AGY_CPUINFO_PATH:-/proc/cpuinfo}"
  [[ -r "$cpuinfo" ]] && grep -Eq '(^|[[:space:]])atomics([[:space:]]|$)' "$cpuinfo"
}

verify_sha256() {
  local file=$1
  local expected=$2
  local actual
  actual=$(sha256sum "$file" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || die "Checksum mismatch for $(basename "$file"). Expected $expected, got $actual."
}

assert_safe_archive() {
  local archive=$1
  local entry

  while IFS= read -r entry; do
    case "$entry" in
      /* | ../* | */../* | */..)
        die "Archive contains an unsafe path: $entry"
        ;;
    esac
  done < <(tar -tzf "$archive")
}

install_packages() {
  info "Installing Termux runtime dependencies"

  pkg install -y glibc-repo
  pkg install -y glibc curl ca-certificates resolv-conf tar coreutils

  if cpu_has_lse; then
    ok "CPU supports ARM LSE atomics"
  else
    info "CPU lacks LSE atomics; installing qemu-user-aarch64"
    pkg install -y qemu-user-aarch64
  fi

  local loader="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
  [[ -x "$loader" ]] || die "Termux glibc loader is missing after package installation: $loader"
}

download_release() {
  local dest=$1

  info "Downloading Antigravity Termux v${RELEASE_VERSION}"
  curl --fail --location --silent --show-error --retry 3 --retry-delay 1 --retry-connrefused --proto '=https' --tlsv1.2 "$RELEASE_URL" --output "$dest"

  verify_sha256 "$dest" "$RELEASE_SHA256"
  ok "Release checksum verified"
}

extract_release() {
  local archive=$1
  local stage=$2

  mkdir -p "$stage"
  assert_safe_archive "$archive"
  tar -xzf "$archive" -C "$stage"

  [[ -f "$stage/agy" && ! -L "$stage/agy" ]] || die "Release archive is missing a regular 'agy' bootstrapper."
  [[ -f "$stage/agy.va39" && ! -L "$stage/agy.va39" ]] || die "Release archive is missing a regular 'agy.va39' engine."

  chmod 0755 "$stage/agy" "$stage/agy.va39"
}

preflight_stage() {
  local stage=$1

  info "Running staged binary preflight"
  "$stage/agy" --version >/dev/null
  ok "Staged binary starts successfully"
}

detect_legacy_wrapper() {
  command -v npm >/dev/null 2>&1 || return 0

  local npm_root
  npm_root=$(npm root -g 2>/dev/null || true)
  [[ -n "$npm_root" ]] || return 0

  local candidate="$npm_root/@bash0816/agy-termux"
  if [[ -d "$candidate" ]]; then
    HAD_LEGACY_PACKAGE=1
    LEGACY_PACKAGE_PATH="$candidate"
  fi
}

backup_current_install() {
  local bin_dir=$1

  BACKUP_DIR="$TMP_DIR/backup"
  mkdir -p "$BACKUP_DIR"

  if [[ -e "$bin_dir/agy" || -L "$bin_dir/agy" ]]; then
    HAD_AGY=1
    cp -a "$bin_dir/agy" "$BACKUP_DIR/agy"
  fi

  if [[ -e "$bin_dir/agy.va39" || -L "$bin_dir/agy.va39" ]]; then
    HAD_ENGINE=1
    cp -a "$bin_dir/agy.va39" "$BACKUP_DIR/agy.va39"
  fi

  if ((HAD_LEGACY_PACKAGE == 1)); then
    cp -a "$LEGACY_PACKAGE_PATH" "$BACKUP_DIR/legacy-package"
  fi
}

install_pair() {
  local stage=$1
  local bin_dir=$2

  mkdir -p "$bin_dir"

  local engine_tmp="$bin_dir/.agy.va39.new.$$"
  local bootstrap_tmp="$bin_dir/.agy.new.$$"

  install -m 0755 "$stage/agy.va39" "$engine_tmp"
  install -m 0755 "$stage/agy" "$bootstrap_tmp"

  mv -f "$engine_tmp" "$bin_dir/agy.va39"
  mv -f "$bootstrap_tmp" "$bin_dir/agy"
}

remove_legacy_wrapper() {
  ((HAD_LEGACY_PACKAGE == 1)) || return 0

  info "Removing legacy @bash0816/agy-termux wrapper"
  npm uninstall -g @bash0816/agy-termux >/dev/null

  # npm owns the agy bin name and may remove our freshly installed bootstrap.
  # Reinstall the verified pair immediately after npm cleanup.
  rm -rf "$HOME/.agy-termux"
}

restore_previous_install() {
  local bin_dir="$PREFIX/bin"

  warn "Install failed; restoring the previous installation"

  rm -f "$bin_dir/agy" "$bin_dir/agy.va39" "$bin_dir/.agy.new.$" "$bin_dir/.agy.va39.new.$"

  if ((HAD_LEGACY_PACKAGE == 1)) && [[ -d "$BACKUP_DIR/legacy-package" ]]; then
    mkdir -p "$(dirname "$LEGACY_PACKAGE_PATH")"
    rm -rf "$LEGACY_PACKAGE_PATH"
    cp -a "$BACKUP_DIR/legacy-package" "$LEGACY_PACKAGE_PATH"
  fi

  if ((HAD_AGY == 1)); then
    cp -a "$BACKUP_DIR/agy" "$bin_dir/agy"
  fi

  if ((HAD_ENGINE == 1)); then
    cp -a "$BACKUP_DIR/agy.va39" "$bin_dir/agy.va39"
  fi
}

cleanup() {
  local status=$?
  set +e

  if ((INSTALL_STARTED == 1 && INSTALL_OK == 0)) && [[ -n "${PREFIX:-}" ]]; then
    restore_previous_install
  fi

  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

  trap - EXIT
  exit "$status"
}

print_check() {
  require_termux

  printf 'platform: native Termux / %s\n' "$(uname -m)"
  printf 'release: v%s\n' "$RELEASE_VERSION"
  printf 'asset: %s\n' "$RELEASE_ASSET"
  printf 'sha256: %s\n' "$RELEASE_SHA256"

  if cpu_has_lse; then
    printf 'cpu: LSE atomics available\n'
  else
    printf 'cpu: no LSE atomics; QEMU fallback required\n'
  fi
}

main() {
  case "${1:-}" in
    --help | -h)
      usage
      return 0
      ;;
    --check)
      print_check
      return 0
      ;;
    "") ;;
    *)
      usage >&2
      die "Unknown argument: $1"
      ;;
  esac

  require_termux
  require_cmd bash
  require_cmd grep
  require_cmd awk

  trap cleanup EXIT
  trap 'exit 130' INT TERM

  printf '%b\n' "${BOLD}termux-agy-arm64${RESET}"
  printf '%b\n' "${DIM}verified native Termux installer${RESET}"
  printf '\n'

  install_packages

  require_cmd curl
  require_cmd tar
  require_cmd sha256sum
  require_cmd install
  require_cmd mv
  require_cmd cp

  TMP_DIR=$(mktemp -d "${PREFIX}/tmp/agy-install.XXXXXX")
  local archive="$TMP_DIR/$RELEASE_ASSET"
  local stage="$TMP_DIR/stage"
  local bin_dir="$PREFIX/bin"

  download_release "$archive"
  extract_release "$archive" "$stage"
  preflight_stage "$stage"

  detect_legacy_wrapper
  backup_current_install "$bin_dir"

  INSTALL_STARTED=1
  install_pair "$stage" "$bin_dir"
  remove_legacy_wrapper
  install_pair "$stage" "$bin_dir"

  hash -r
  "$bin_dir/agy" --version
  INSTALL_OK=1

  printf '\n'
  ok "Installed Antigravity CLI v${RELEASE_VERSION}"
  printf 'Run: %bagy%b\n' "$BOLD" "$RESET"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
