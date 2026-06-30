# Maintenance Manual

## Weekly

- Let the daily backup timer run and confirm that a fresh archive was created.
- Review the last backup archive and the prune output.
- Check `spark` metrics if an in-game performance complaint was reported.

## Monthly

- Apply OS updates through the maintenance window.
- Review plugin release notes before updating.
- Verify the backup restore path on a non-production copy if possible.
- Confirm that the current 7-backup retention is still acceptable for disk pressure.

## Update discipline

- Update the OS separately from Minecraft runtime updates when practical.
- Update Purpur before plugin upgrades if a major protocol bump is involved.
- Keep a clean rollback point before any change that affects gameplay or authentication.
