# Upgrade Guide

## Purpur upgrades

Purpur is resolved at update time. The recommended path is:

1. Create or confirm a backup.
2. Stop the service.
3. Run `scripts/update.sh`.
4. Start the service and watch the journal.
5. Keep the previous release directory until the new one is proven.

## Plugin upgrades

- Update one plugin family at a time when possible.
- Keep the prior jar in the backup history.
- Restart after the change.
- Verify login, permissions, and Bedrock connectivity after each major plugin group.

## OS upgrades

- Apply point updates normally.
- Treat kernel or libc changes as maintenance events.
- Reboot during a planned window, not ad hoc.

