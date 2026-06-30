# Configuration Reference

## Host paths

- `/home/minecraft/server` - active server tree
- `/home/minecraft/server/backups` - compressed backups
- `/home/minecraft/server/logs` - server and bootstrap logs
- `/home/minecraft/server/configs` - generated configuration and secrets
- `/home/minecraft/server/plugins` - plugin jars
- `/home/minecraft/server/releases` - versioned Purpur downloads
- `/home/minecraft/server/scripts` - server-local helper scripts

## Configuration files

- `server.env` - JVM and service environment
- `server.properties` - core Minecraft options
- `motd.txt` - branding text
- `plugins.manifest` - plugin download manifest
- `server.env.example` - documented environment template
- `server.properties.example` - documented game-settings template
- `first-join.txt` - policy text shown to new players

## Security-sensitive values

- SSH keys
- RCON password
- DiscordSRV token
- Any database credentials if added later
