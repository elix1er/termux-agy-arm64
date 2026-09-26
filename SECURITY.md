# Security

## Report a problem

Do not open a public issue for a vulnerability involving credentials, arbitrary code execution, or supply-chain compromise. Use GitHub's private vulnerability reporting for this repository when available, or contact the repository owner privately.

## Installer trust boundary

The installer:

- downloads one pinned release asset over HTTPS;
- verifies its SHA-256 before extraction;
- rejects unsafe archive paths;
- does not vendor Google's Antigravity binary;
- does not collect telemetry.

A changed release URL, digest, bootstrapper, or workflow dependency is security-sensitive and should be reviewed as such.
