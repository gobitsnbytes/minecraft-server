# bits&bytes Minecraft Infrastructure

Production-grade Debian 12 infrastructure for the official bits&bytes Minecraft server.

This repository is intentionally opinionated:

- Debian 12 Bookworm base
- Java 21 LTS
- Purpur as the server runtime
- Paper-compatible plugin stack
- systemd-managed service lifecycle
- explicit hardening, logging, backups, and recovery

The design goal is not just "a server that runs". It is a server that can be
operated, maintained, audited, upgraded, and restored like production
infrastructure.

## What is included

- Phase 0 architecture and risk analysis
- Host hardening bootstrap scripts
- Minecraft runtime installation scripts
- Plugin installation and update automation
- Backup, restore, restart, shutdown, and health-check scripts
- systemd unit files and timers
- operational documentation

## Current design decisions

- The host is treated as a single-node production system.
- Minecraft never runs as root.
- SSH is key-only.
- The server is kept in `/home/minecraft`.
- Purpur is downloaded at install/update time from the official API.
- Plugins are fetched from their upstream official release channels when possible.
- Backups are compressed and retained locally, with an easy future path to off-site sync.

## Structure

```text
docs/        Architecture, installation, operations, recovery, upgrade, troubleshooting
scripts/     Shell entrypoints and shared helpers
systemd/     systemd unit and timer files
config/      Example runtime configuration and policy templates
```

## Quick start

1. Review [`docs/architecture.md`](docs/architecture.md)
2. Read [`docs/installation-guide.md`](docs/installation-guide.md)
3. Run `scripts/bootstrap-host.sh` as root on the Debian VPS
4. Run `scripts/install-minecraft.sh` as root
5. Follow the post-install verification steps in the installation guide

## Foundation references

- [gobitsnbytes.org](https://gobitsnbytes.org)
- [Code of Conduct](https://gobitsnbytes.org/coc)
- [Privacy Policy](https://gobitsnbytes.org/privacy)
- [Terms](https://gobitsnbytes.org/terms)
