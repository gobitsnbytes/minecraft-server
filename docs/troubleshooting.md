# Troubleshooting Guide

## Service will not start

- Check `journalctl -u bnb-minecraft -b`
- Verify `java -version`
- Verify `server.env`
- Confirm the Purpur jar exists and is readable by `minecraft`

## Players cannot join

- Check UFW rules and port exposure
- Confirm the service is listening on the expected game ports
- Verify `server.properties` values
- Verify Geyser/Floodgate configuration for Bedrock

## Cracked auth issues

- Confirm nLogin is loaded and its config matches the online-mode setting
- Check for name collisions or authentication database problems
- Verify that premium and cracked auth flows are documented for staff

## High TPS loss

- Run `spark` diagnostics
- Check for entities, hoppers, redstone, or chunk generation
- Confirm the pre-generation completed
- Reduce view/simulation distance if necessary

