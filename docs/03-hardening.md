# 03 - Hardening

Each measure follows the pattern: **Threat (ID) → Solution → Configuration → How verified**.

"Verified 2026-11-12" means I read the state on that day with read-only commands.
"Not re-checked" means the statement comes from my own notes and I did not look at it again for this document.
Network measures are in [04](04-network-access.md), backups in [07](07-backup-restore.md).

## H1 - Automatic security updates

- **Threat:** T12 (outdated software), T1
- **Solution:** `unattended-upgrades` installs Debian security updates daily. A custom origin entry covers the Tailscale package repository.
- **Configuration:** The standard Debian periodic-update settings, plus a second drop-in file for the Tailscale repository.
- **How verified:** Verified 2026-11-12: both files exist, the service is enabled.
- **Gap:** Container images and some other software are updated by hand. See H8.

## H2 - SSH: key-only, no root, limited reach

- **Threat:** T1, T4, T5
- **Solution:** No passwords, no root login, few tries, short login window. The service account of the AI agent cannot log in over SSH. SSH is reachable only from the LAN and through Tailscale (see [04](04-network-access.md)).
- **Configuration:** [`configs/ssh/10-hardening.conf`](../configs/ssh/10-hardening.conf), [`configs/ssh/90-deny-claude.conf`](../configs/ssh/90-deny-claude.conf). `PasswordAuthentication no` and `KbdInteractiveAuthentication no` are set in the main `/etc/ssh/sshd_config`, not in a drop-in.
- **How verified:** Verified 2026-11-12 with the effective SSH configuration: password and keyboard-interactive logins off, root login off, public-key login on, few attempts, short login window, X11 forwarding off, the agent user denied, empty passwords refused.
- **Planned:** SSH forwarding will be disabled. Other SSH options from the Lynis baseline are unchanged.

## H3 - Accounts and sudo

- **Threat:** T6, T7, T3
- **Solution:** Two accounts: my own admin account (sudo with password, not used by the agent) and a dedicated account `claude` for the AI agent. The agent account is not in the `docker` group. It has **one** SSH key, a deploy key for publishing this repository (see [06 R7](06-remote-claude-code.md)). It has no key for logging in to the server. Its sudo rights are an allowlist of exact commands (since 2026-11-15).
- **Configuration:** A root-owned sudoers file with about fifty exact commands, run as root only, no wildcards. Sanitized copy: [`configs/sudoers/claude-allowlist`](../configs/sudoers/claude-allowlist). Before 2026-11-15 the account had passwordless sudo for everything, which made it effectively root.
- **How verified:** Verified 2026-11-15: the agent's sudo list shows only the allowlist. A test of 41 allowed and 38 refused commands passed (details in [06 R8](06-remote-claude-code.md)). Verified 2026-11-12: the agent account is in no extra groups, and the `docker` group has no members. The agent's SSH folder was created on 2026-11-12 and holds only the deploy key pair, a config entry and the pinned GitHub host keys.
- **Limits:** The agent can still read some logs and four compose files, and it keeps its deploy key. Other limitations are listed in [06 R8](06-remote-claude-code.md).

## H4 - Kernel and system settings

- **Threat:** T1, T2
- **Solution:** Debian defaults plus a few checked values.
- **Configuration:** SYN cookies on, ICMP redirects off, kernel log restricted. IP forwarding is on because Docker and Tailscale need it.
- **How verified:** Verified 2026-11-12 with `sysctl`. AppArmor is active (`systemctl is-active apparmor`).
- **Gap:** Lynis reports several more sysctl values that differ from its profile (KRNL-6000). Not changed yet.

## H5 - File permissions and secrets on disk

- **Threat:** T13, T3, T8
- **Solution:** Secret files are readable only by their owner. The home directories are mode 700.
- **Configuration:** Mode 600 for the `.env` files of the Minecraft and dynamic DNS stacks, the alert settings, the backup password file and the oCIS configuration (owned by the container user). The Netdata notification config is readable by root and the Netdata group only.
- **How verified:** Verified 2026-11-12 with `stat`. The Pi-hole change below was done and checked by the owner on 2026-11-15. I did not re-check it (the allowlist does not let the agent read that stack).
- **Changed 2026-11-15, Pi-hole web password (before / after):**
  - **Before:** the password was written in plain text in the compose file (mode 664). Only the 700 home directory protected it.
  - **After:** the password is in a `.env` file (mode 600). The compose file only references the variable and is mode 600. The password was rotated on 2026-11-15, so the old value counts as exposed and is no longer valid. The sanitized copy is [`configs/docker-compose/pihole.yml`](../configs/docker-compose/pihole.yml).
- **Known gaps:**
  - The oCIS configuration file must contain service secrets that oCIS needs at start-up. They cannot be removed, only protected by permissions.

## H6 - Container isolation

- **Threat:** T3
- **Solution:** No privileged containers, no Docker socket mounted into any container, only the capabilities that are needed.
- **Configuration:** Minecraft needs one extra capability (for autopause). Pi-hole needs three. oCIS uses host networking. Each other stack has its own bridge network. See [`configs/docker-compose/`](../configs/docker-compose/).
- **How verified:** Verified 2026-11-12 with `docker inspect`: no container is privileged, no container mounts the Docker socket, capabilities as listed.
- **Gap:** oCIS runs in the host network namespace, so it can reach everything that listens on localhost (for example the Netdata statsd port). Containers do not run with a read-only root filesystem or a custom seccomp profile.

## H7 - Bluetooth and unused services

- **Threat:** T2
- **Solution:** Bluetooth is turned off and disabled. Only the services in the [architecture](02-architecture.md) run.
- **How verified:** Verified 2026-11-12: `systemctl list-units --type=service --state=running` shows no Bluetooth service. The list of listening sockets (`ss -tulnp`) shows only the expected services.

## H8 - Updating container images and other software

- **Threat:** T12, T8
- **Solution:** Updates are applied manually. Before an update, the old image is kept under a rollback tag so that I can go back. A monthly routine is planned.
- **How verified:** Verified 2026-11-12 with `docker images`: rollback tags exist for the updated images.
- **Open:** Several images still use `latest` tags. There is no written test checklist for updates.

## H9 - Power and lid behaviour

- **Threat:** T10
- **Solution:** Closing the lid does not suspend the notebook.
- **Configuration:** The lid switch is set to "ignore" in the login manager settings.
- **How verified:** Verified 2026-11-12 by reading the file.

## Considered, not needed

| Measure | Decision and reason |
|---|---|
| Fail2ban | **Not used, because SSH is only reachable with a key and only from the LAN and through Tailscale.** There is no password to guess and no public SSH port to attack. Lynis suggests it (DEB-0880). It would also add firewall rules that I would have to maintain. Revisit if SSH is ever exposed to the internet. |
| Full-disk encryption of the server disk | Not used. Accepted risk T11 (see [01](01-threat-model.md)). |
| GRUB password | Not used. Needs physical access, which is out of scope (T11). |

## Open hardening items (summary)

See the "Planned" list in the [README](../README.md). Done: the `claude` sudo allowlist (H3) and the Pi-hole password (H5).
