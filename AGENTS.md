# AGENTS.md

## Scope

This repository owns the **installation and verification path** for running the community-patched Antigravity CLI build on native Termux/Android ARM64.

It does not own Google's CLI, authentication, model behavior, or the binary patching implementation maintained upstream.

## Hard rules

1. Keep the default install deterministic. Never replace a pinned release with a moving `latest` or branch URL.
2. Verify the release archive before extraction. A missing or mismatched digest is a hard failure.
3. Keep `agy` and `agy.va39` as an inseparable pair. Never document `agy.va39` as the user-facing command.
4. Stage and preflight before replacing an existing installation. A failed install must leave the previous pair usable.
5. Do not silently install Node.js. The standalone path does not require it.
6. Only install QEMU when the device lacks ARM LSE atomics.
7. Do not weaken native-Termux and `aarch64` checks to make CI green. Tests should mock the environment instead.
8. Do not vendor or redistribute Google's binary in this repository.
9. Keep third-party attribution factual. Do not imply endorsement by Google or community maintainers.
10. Do not add telemetry.

## Shell style

- Bash with `set -Eeuo pipefail`.
- Quote expansions unless word splitting is intentional.
- Prefer small functions with explicit names over long inline command chains.
- Use `mktemp -d` and traps for temporary state.
- Error messages must say what failed and what the user can do next.
- Output should stay readable on a phone-sized terminal.
- `shellcheck`, `shfmt`, and `bash -n` must pass.

## Release pin

The installer's release version, download URL, and SHA-256 form one reviewed unit. When bumping the release:

1. Read the GitHub release metadata.
2. Confirm the asset is `antigravity-termux-standalone.tar.gz`.
3. Copy GitHub's published `sha256:` digest.
4. Update the pin in one commit.
5. Run `./scripts/check.sh`.
6. Let the upstream-watch workflow confirm the pin.

Never infer a checksum from a version number or copy it from an untrusted comment.

## Git

Use Conventional Commits:

```text
feat(installer): ...
fix(installer): ...
test(installer): ...
ci: ...
docs: ...
chore: ...
```

Keep commits reviewable. Do not combine a release-pin change with unrelated documentation or CI refactors.

Major installer, runtime, release, or workflow changes go through a pull request. Repository bootstrap documentation may land directly on `main`.

## Writing

Keep project prose concrete and short. Avoid marketing claims, fake urgency, filler, decorative emoji headings, and generic generated-sounding phrasing. Explain the failure mode, mechanism, and recovery command directly.
