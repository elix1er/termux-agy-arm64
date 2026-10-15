# termux-agy-arm64

<p align="center">
  <strong>Antigravity CLI on native Termux/ARM64, installed deterministically.</strong>
</p>

<p align="center">
  <a href="https://github.com/elix1er/termux-agy-arm64/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/elix1er/termux-agy-arm64/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/elix1er/termux-agy-arm64/actions/workflows/upstream-watch.yml"><img alt="Upstream watch" src="https://github.com/elix1er/termux-agy-arm64/actions/workflows/upstream-watch.yml/badge.svg"></a>
  <img alt="platform" src="https://img.shields.io/badge/platform-Termux%20%7C%20Android%20ARM64-111111">
  <img alt="shell" src="https://img.shields.io/badge/installer-Bash-111111">
</p>

> Community compatibility installer. This project is not affiliated with, endorsed by, or sponsored by Google.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/elix1er/termux-agy-arm64/main/install.sh | bash
```

Then run:

```bash
agy
```

The installer is designed for **native Termux on Android ARM64**. It installs the required Termux packages, removes the incompatible npm wrapper when present, handles non-LSE CPUs with QEMU, verifies the pinned release archive by SHA-256, stages both required binaries, runs a preflight, and only then replaces the installed copy.

## Why

The official Linux ARM64 Antigravity binary is not a native Android/Bionic binary. On affected Termux devices, an unpatched build can die during startup with:

```text
syscall.faccessat2(...)
SIGSYS: bad system call
```

Android's seccomp policy can reject the `faccessat2` path before the CLI reaches its UI. The standalone Termux build produced by [wallentx/antigravity-cli-termux](https://github.com/wallentx/antigravity-cli-termux) patches the engine for Termux/VA39 compatibility and ships it with a native bootstrapper.

This repository focuses on the part that should be boring: **getting that build onto a phone safely and repeatably**.

| Install concern | This repo |
| --- | --- |
| Moving upstream installer | No; release version and digest are pinned |
| Payload integrity | SHA-256 checked before extraction |
| Existing broken npm wrapper | Detected and removed |
| Termux glibc | Installed automatically |
| CPU without ARM LSE atomics | Installs the QEMU fallback |
| Partial replacement | Staged install with rollback |
| Twin-binary requirement | Verifies and installs both `agy` and `agy.va39` |
| Post-install sanity check | Runs `agy --version` |

## Compatibility

- Native Termux
- Android ARM64 / `aarch64`
- Termux glibc packages
- LSE-capable CPUs natively
- Older ARM64 CPUs through `qemu-user-aarch64`

PRoot is intentionally out of scope. A normal Linux userspace can use Google's official installer instead.

## Supply-chain model

The repository does **not** vendor Google's Antigravity binary.

The installer downloads a specific release artifact from the community Termux port and checks it against the SHA-256 digest published by GitHub for that release. Maintainers update the pin through review, with CI checking that the configured digest still matches GitHub's release metadata.

For an additional provenance check after downloading an archive manually:

```bash
gh attestation verify antigravity-termux-standalone.tar.gz \
  -R wallentx/antigravity-cli-termux
```

Google Antigravity CLI remains subject to Google's terms and licensing. The Termux compatibility build is maintained by its respective community project.

## Recovery

If an older `@bash0816/agy-termux` installation is crashing with `SIGSYS`, the normal install command above is the migration path. You do not need Node.js for this installer.

Useful diagnostics:

```bash
uname -m
grep -m1 -o 'atomics' /proc/cpuinfo || true
command -v agy || true
agy --version
```

Keep `agy` and `agy.va39` together. Always launch `agy`; the bootstrapper selects the correct execution path.

## Development

```bash
git clone https://github.com/elix1er/termux-agy-arm64.git
cd termux-agy-arm64
./scripts/check.sh
```

Changes use Conventional Commits. Installer behavior changes go through pull requests and must keep the checksum pin, staging, rollback, and twin-binary checks intact.

See [AGENTS.md](AGENTS.md) before changing installer or release logic.

## License

The installer and documentation in this repository are licensed under the [MIT License](LICENSE). Downloaded Antigravity binaries are not covered by this license and remain subject to their respective terms.

## Credits

Compatibility work that made native Termux execution possible comes from the Antigravity CLI community, including [wallentx](https://github.com/wallentx/antigravity-cli-termux), [Brajesh2022](https://gist.github.com/Brajesh2022/e42160d29b55417db6c18c52dd1d6d37), [hjotha](https://github.com/hjotha), and earlier Termux wrapper work by [bash0816](https://github.com/bash0816/agy-termux).

Upstream CLI: [google-antigravity/antigravity-cli](https://github.com/google-antigravity/antigravity-cli)
