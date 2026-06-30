# Installation Guide

## Prerequisites

- Debian 12 VPS
- Root SSH access for the initial bootstrap only
- Existing SSH key access for the operator account

## Installation steps

1. Clone or copy this repository onto the host.
2. Run `scripts/bootstrap-host.sh` as root.
3. Run `scripts/install-runtime.sh` as root.
4. Run `scripts/install-minecraft.sh` as root.
5. Review `/home/minecraft/server/configs/server.env`.
6. Start the service with `systemctl start bnb-minecraft`.
7. Watch the journal with `journalctl -fu bnb-minecraft`.
8. Once the service is healthy, run `scripts/pregen-world.sh`.
9. Enable and verify timers for backup and health checks.

## Notes

- The bootstrap script is idempotent where practical.
- SSH hardening is applied carefully so existing key access is preserved.
- The install scripts create a dedicated `minecraft` account and never run the game as root.
- The server is configured for cracked Java authentication because that is a stated requirement; this is documented as a security tradeoff.

