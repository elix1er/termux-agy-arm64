# Contributing

Keep changes small enough to review from the diff.

## Before opening a PR

Run:

```bash
./scripts/check.sh
```

Use Conventional Commits for commits and the pull request title.

Installer changes must preserve four properties:

1. the release is pinned;
2. the archive digest is verified before extraction;
3. both `agy` and `agy.va39` are staged and preflighted before replacement;
4. a failed replacement restores the previous install.

When updating the upstream release, change the version and SHA-256 together in one focused commit. Use the digest published in GitHub release metadata.

Do not commit downloaded Antigravity binaries, credentials, local Termux state, or generated archives.
