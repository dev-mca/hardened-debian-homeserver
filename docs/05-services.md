# 05 - Services (Docker, Pi-hole, Minecraft, cloud storage)

Pattern: **Threat (ID) → Solution → Configuration → How verified**.
Each stack lives in its own folder `~/docker/<name>/` with a `docker-compose.yml`. Data is stored next to it (bind mounts).
Sanitized compose files are in [`configs/docker-compose/`](../configs/docker-compose/).

Manage a stack: `cd ~/docker/<name> && sudo docker compose up -d | logs -f | pull`.

## S1 - Docker stacks

| Stack | Image | Reachable from |
|---|---|---|
| `npm` | Nginx Proxy Manager | LAN, Tailscale |
| `pihole` | Pi-hole | LAN, Tailscale |
| `ocis` | oCIS | LAN, Tailscale |
| `duckdns` | dynamic DNS updater | outbound only |
| `minecraft` | Paper server + backup container | internet (game port) |

- **Threat:** T3, T12, T13
- **Solution:** One stack per service, no privileged containers, no Docker socket in containers (see [03 H6](03-hardening.md)). Secrets for the dynamic DNS, Minecraft and Pi-hole stacks come from `.env` files (mode 600).
- **How verified:** Verified 2026-11-12 with `docker ps` and `docker inspect`.
- **Known gaps:** Image tags are not pinned (T12). (The Pi-hole password used to be in plain text in its compose file. Moved to a `.env` file on 2026-11-15, see [03 H5](03-hardening.md).)

## S2 - Minecraft (the only public service)

- **Threat:** T1, T3
- **Solution:**
  - Whitelist on and enforced. Only invited players can join. Online mode on (valid Minecraft accounts only).
  - No operators and no cheats. Admin work goes through `rcon-cli` inside the container. The remote-console port is not published.
  - Pinned Minecraft version and a current Paper build, updated by hand.
  - Memory for the game server is limited. Autopause freezes the JVM after a period without players, so an idle server costs no CPU. RAM stays reserved while it is paused.
  - A custom server plugin (a small Java plugin that makes skeleton arrows less accurate). Its source is not part of this repo.
- **Configuration:** [`configs/docker-compose/minecraft.yml`](../configs/docker-compose/minecraft.yml). Player names are replaced by `<PLAYER_1>` to `<PLAYER_3>`.
- **How verified:** Verified 2026-11-12: the compose file and the running container ("healthy"). The whitelist, online mode and RCON setting come from the compose file.
- **Residual risk:** The server must be reachable by name or IP from the internet, so it is exposed to scanners and to bugs in the game server. Scanner bots were seen and rejected by the whitelist (from my notes, 2026-10-31). A connection limit per IP was offered but not set up.
- **Autopause note:** While the JVM is paused, `rcon-cli` does not work. A connection attempt to 25565 wakes it. Bots and status checkers wake it for a short time too. Wake-up and join were tested with raw TCP, not yet with a real client.

## S3 - Cloud storage (oCIS)

- **Threat:** T2, T4, T9, T11, T13
- **Solution:** Reachable only from the LAN and Tailscale. It uses a self-signed certificate (browsers warn). The data folder and the config folder are owned by the container user and not readable by others. The bootstrap admin password in the config file is a random value that is no longer valid. The real admin password was changed in the web interface, and a personal admin account exists. Backed up nightly (see [07](07-backup-restore.md)).
- **Configuration:** [`configs/docker-compose/ocis.yml`](../configs/docker-compose/ocis.yml). `OCIS_URL` contains the server's LAN address, so it must change if that address changes. The router reserves the address.
- **How verified:** Verified 2026-11-12: modes of the config folder and config file (`stat`), the container is running. The mode of the data folder comes from the 2026-11-11 audit notes. The state of the admin password comes from the audit on 2026-11-11 (LDAP bind test), not re-checked today.
- **Open:** The oCIS config file still contains internal service secrets in plain text (they cannot be removed, only protected). The certificate is self-signed. Option: a certificate from Tailscale, not done.
- **Update:** oCIS was updated to a version with security fixes on 2026-11-11. The old image is kept for rollback.

## S4 - Reverse proxy (Nginx Proxy Manager)

- **Threat:** T2, T4
- **Solution:** It has one proxy host, the internal cloud name, which redirects to the oCIS address. That host is HTTP only (no certificate). Non-LAN clients get 403 (see [04 N5](04-network-access.md)). The admin UI is LAN-only and uses a strong password.
- **How verified:** The proxy host list and the password strength come from my notes (2026-10-30 and 2026-11-11), not re-checked.

## S5 - Pi-hole

- **Threat:** T8, T4
- **Solution:** Pi-hole gives DNS to the household. Its web UI needs a password, which comes from a `.env` file (mode 600, rotated 2026-11-15). DNS and UI are LAN-only (and Tailscale). The time zone is the same as the host's (aligned 2026-11-15).
- **How verified:** Verified 2026-11-12: compose file and running container ("healthy"). Password move, file modes and time zone were done and confirmed by the owner on 2026-11-15, not re-checked by me.
- **Change control:** Pi-hole and DNS affect the whole family. I do not restart or update it without asking first.

## S6 - Dynamic DNS

- **Threat:** T2, T13
- **Solution:** A small container updates the public name for the game server regularly. The token lives only in a `.env` file (mode 600). The name resolves to the home IP address, so it is not published here.
- **How verified:** Verified 2026-11-12: the container runs, the token file has mode 600.

## S7 - Netdata

- **Threat:** T3, T10
- **Solution:** Local dashboard, reachable from the LAN. Machine learning is off to save RAM. The agent is not connected to Netdata Cloud, and anonymous statistics are off. Sensitive functions (processes, journal, connections) need a cloud login, so the LAN gets "412".
- **Configuration:** [`configs/netdata/netdata.conf`](../configs/netdata/netdata.conf). 
- **How verified:** Verified 2026-11-12: the service runs. The cloud and function-access statements come from my notes.
- **Known limit:** Netdata uses a noticeable share of the RAM. Its own updater is disabled, so updates are manual.

## Memory budget

RAM is tight (8 GB): Minecraft (its memory is reserved even when paused), Netdata, oCIS, Pi-hole and the Claude Code processes share it. A RAM upgrade is still planned (one free slot).
