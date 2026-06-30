# Operations Manual

## Daily checks

- Confirm the service is active: `systemctl status bnb-minecraft`
- Review recent logs: `journalctl -u bnb-minecraft -n 200`
- Check health output: `scripts/health-check.sh`
- Confirm backup freshness in `/home/minecraft/server/backups`

## Normal control

- Start: `systemctl start bnb-minecraft`
- Stop: `systemctl stop bnb-minecraft`
- Restart: `scripts/restart.sh`
- Shutdown: `scripts/shutdown.sh`

## What to watch

- CPU spikes during chunk generation or plugin reloads
- Heap usage relative to the configured `Xmx`
- Disk growth from world data, logs, and backups
- Unexpected authentication issues after plugin changes

## Operational principles

- Avoid plugin reloads unless a plugin explicitly documents safe reload behavior.
- Prefer a full restart after plugin or config changes.
- Keep release notes and update notes in the repo so changes remain auditable.

