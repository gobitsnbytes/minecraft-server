# Disaster Recovery Guide

## Recovery priorities

1. Restore the most recent known-good backup.
2. Restore the Purpur release pointer if the runtime changed.
3. Restore plugins and configs.
4. Verify startup in a controlled window.
5. Re-enable timers and monitoring.

## Recovery workflow

1. Stop the service.
2. Move the broken state aside instead of deleting it.
3. Restore the selected archive with `scripts/restore.sh`.
4. Start the service and inspect the journal.
5. Confirm login, world load, and plugin initialization.

## Important guidance

- Do not attempt to "repair" a corrupted world by editing files manually unless the corruption is understood.
- Preserve the broken state for later analysis.
- If the filesystem itself is at risk, snapshot or copy data off-host before repair attempts.

