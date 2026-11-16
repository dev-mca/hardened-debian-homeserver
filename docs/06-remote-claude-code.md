# 06 - Remote Claude Code

An AI agent (Claude Code) helps me administer the server. It runs on the server as a systemd service in
"remote control" mode, so I can talk to it from the Claude app or the web. This page describes how it is set up,
what it can reach, what is deliberately excluded and how damage is limited.

Pattern: **Threat (ID) → Solution → Configuration → How verified**.

## R1 - Dedicated non-root account

- **Threat:** T7, T6
- **Solution:** The agent runs as its own user `claude`, not as root and not as my admin account. This user cannot log in over SSH, is not in the `docker` group and cannot read my home directory (mode 700). Its only SSH key is the deploy key described in R7. Its sudo rights are a short allowlist of exact commands (R8).
- **Configuration:** [`configs/systemd/claude-remote.service`](../configs/systemd/claude-remote.service) (`User=claude`, `Restart=always`). SSH ban: [`configs/ssh/90-deny-claude.conf`](../configs/ssh/90-deny-claude.conf).
- **How verified:** Verified 2026-11-12: `id claude` (groups `claude`, `users`), `systemctl cat claude-remote`, `sshd -T` shows `denyusers claude`, the service is enabled. `/home/claude/.ssh` holds only the deploy key (R7).

## R2 - Permission mode and rules

- **Threat:** T7
- **Solution:** The service starts Claude Code with `--permission-mode auto`. In this mode a classifier decides whether a tool call may run without asking. A few local rules add to it. The sudo allowlist (R8) is the control that counts for root rights, because the classifier and these rules only decide what the agent may try.
- **Configuration:** The service line in the unit file and the agent's own settings file. Allowed without asking: one read-only firewall status command and editing the agent's own notes file. Denied: recursive file removal through sudo.
- **How verified:** Verified 2026-11-15 by reading both files (one firewall rule was narrowed on that day).
- **Observed behaviour (from my notes, not re-tested):** The classifier blocked things like creating a new systemd unit ("unauthorized persistence"), a script run as root for firewall changes, credential tests, and `docker compose pull/up` on shared services. In those cases I installed the unit myself or told the agent explicitly to go on.
- **Rule for the agent:** It must confirm with me before it restarts containers or changes network or firewall settings, because other people at home depend on DNS and the cloud. This rule lives in the agent's notes file.
- **Why auto mode?** I give tasks from my phone and rely on the sudo allowlist and the permission rules.

## R3 - Working directory

- **Threat:** T7
- **Solution:** The service starts in a subfolder of the agent's home, not in the home directory itself. Claude Code refuses to run in a home directory that has no saved trust. The agent keeps notes and copies of the scripts there.
- **How verified:** Verified 2026-11-12 in the unit file (`WorkingDirectory=`).

## R4 - Access only through Tailscale and outbound connections

- **Threat:** T2, T6
- **Solution:** The remote-control service opens no listening port. It connects out to the Claude service. My own SSH access to the server goes through the LAN or Tailscale only (see [04](04-network-access.md)).
- **How verified:** Verified 2026-11-12 with `ss -tulnp`: no listening socket belongs to the Claude Code process.

## R5 - Deliberately excluded access

| Not allowed | How it is enforced |
|---|---|
| SSH login as the agent user | `DenyUsers claude` |
| Docker socket | The user is not in the `docker` group. Through sudo, only the exact `docker` commands in R8. |
| My home directory (docker stacks, `.env` files, my SSH keys) | Mode 700. Through sudo, the agent can read four compose files that hold no secrets (R8). |
| Shells, editors, `rm`, `tee`, `cp`, `chmod` and other file changes as root | Not in the sudo allowlist (R8). The deny rule for `sudo rm *` is an extra. |
| Firewall changes, package installs, new or edited units | Not in the sudo allowlist (R8). I do them from my admin account. |
| Pre-approved changes to shared services (DNS, cloud) | Rule in the agent's notes, plus the classifier |
| Secrets in chat or in files | Rule in the agent's notes ("do not print secrets"). The agent does not read the oCIS secrets or the backup password. |

## R6 - Damage limitation

| Measure | Where |
|---|---|
| Nightly encrypted backup, root-only (the agent can only start a run) | [07](07-backup-restore.md) |
| Rollback images for all updated containers | [03 H8](03-hardening.md) |
| Backups of every changed config next to the original (`.bak-<date>`) | Habit, visible on the system |
| Push alerts for outages | [08](08-monitoring-logging.md) |
| The agent's changes are written to its notes file after each step | Notes file, copied to the backup |

## R7 - Deploy key for this repository

- **Threat:** T6, T7, T13
- **Solution:** To publish this documentation, the `claude` account has a dedicated ed25519 key pair, created on 2026-11-16 with no passphrase (it must work unattended). It replaces an earlier key of the same kind, which was deleted. It is registered on GitHub as a **deploy key with write access to this one repository** and nowhere else. It is not reused from any other key and not loaded into an ssh-agent.
- **Configuration:** The agent's SSH configuration uses only this key for GitHub and does not use an ssh-agent. GitHub's host keys are pinned after I compared their fingerprints with the official list. The key file is readable only by its owner.
- **How verified:** Verified 2026-11-12 by listing the key folder and the pinned host keys (three key types).
- **Honest limit:** The private key is a file of the `claude` account, so **anyone who controls that account can read it**. The key has no passphrase. The scope is the damage limit.
- **Mitigation:**
  - The key can only reach one repository.
  - A GitHub ruleset on the default branch (`main`) is active (stated by the owner, 2026-11-16): the branch cannot be deleted and cannot be force-pushed. It does **not** require pull requests, because the deploy key pushes directly. So a compromised key can still add new commits to `main` (visible in the history, but not removable by that key), and the ruleset does not cover other branches. Not re-checked by me, the key cannot read the repository settings.
  - The key can be revoked at any time in the repository settings. Revoke it if the account is suspected to be compromised, or when the repository is finished.
  - The repository contains no secrets (checked before each push, see `scripts/check-secrets.sh`).
- **Backup note (done 2026-11-12):** The nightly backup includes the agent's home, which first would have stored the private deploy key in the backup archive. The key file is now on the backup's exclude list ([`configs/backup/mca-backup.exclude`](../configs/backup/mca-backup.exclude)). The public key, the SSH configuration and the pinned host keys stay in the backup on purpose. The old exclude file was copied first.
  - **How verified:** Dry runs of the backup with the exclude list listed the private key **before** the change and did **not** list it **after**. The dry runs wrote nothing. The key was created after the last snapshot of that day, so no older snapshot contains it. On 2026-11-15 I listed the agent's key folder in the three latest system snapshots, and none of them contains the private key.

## R8 - Sudo allowlist (since 2026-11-15)

- **Threat:** T6, T7, T3
- **Before (until 2026-11-15):** The agent had passwordless sudo for every command, so it was effectively root. "Not in the docker group" and "`sudo rm` is denied" did not hold: any other sudo command could do the same.
- **After:** The agent may run only a list of about fifty exact commands as root, with absolute paths and fixed arguments, without wildcards and without environment overrides. The old rule was removed and kept in a backup outside the live configuration (the rollback). A sanitized copy of the list is in [`configs/sudoers/claude-allowlist`](../configs/sudoers/claude-allowlist).
- **What the agent may run through sudo:** read-only status and log queries (firewall, network, containers, named services, disk health, a few configuration files without secrets) and a handful of fixed restarts of my own services.

- **Not allowed, on purpose:**

| Left out | Why |
|---|---|
| Shells, interpreters, editors, pagers | They run any code. |
| `tee`, `cp`, `mv`, `install`, `sed`, `chmod`, `chown`, `mkdir`, `rm` | Writing files as root means root. |
| `docker run`, `docker exec` with free arguments, `docker inspect`, `docker compose` | A container with host mounts is root. `inspect` prints environment secrets. |
| `ufw allow/delete/reload`, `iptables-restore` | Whoever changes the firewall can open everything. |
| `apt-get install` | Package scripts run as root. |
| `systemctl edit/enable/daemon-reload`, new units | They would change code that root runs. |
| `restic` | It needs the backup password, and `restore` can write anywhere. |
| Reading arbitrary files | They would reveal password hashes, secret files and keys. |
| `sudo -u <other user>`, `su` | Only root is allowed as target. |

- **About `NOEXEC`:** The read-only group carries a `NOEXEC` tag. I do not count it as protection. The exact-argument rules are what protects.
- **Effect on daily work:** Changes to configs, scripts, units, firewall rules, packages and compose files are made by me from the admin account, on the agent's proposal. The agent can no longer start the debug bridge that I use for the monitoring phone. I start it by hand when needed.
- **How verified (2026-11-15):**
  - The agent's sudo rights list shows three rules, all from the new file, and **no** passwordless blanket rule. The commands are identical to the prepared file.
  - Positive test: 41 of 41 allowed commands work. The two harmless changes that were tried (a service restart and a container start) work too.
  - Negative test: 38 of 38 commands outside the list are refused. They covered shells, container escapes, reading secret files, writing files as root, changing units, firewall changes, package installs, the backup tool, switching to other users and environment overrides. Nothing was executed or created.
  - Read-only review: only the new file matches the agent. There is no polkit, `pkexec` or `doas`, and the other privilege-escalation helpers are denied. No file outside the agent's home and the temp folders is writable for the agent. None of the inputs of the monitoring, backup and Netdata services can be changed by the agent. The effective rules were read through sudo itself, not from the root-only files.
- **Known limitations (one sentence each):**
  - The agent can still read the logs of the six containers, of the named services and four compose files.
  - The agent can send values to the local Netdata statsd port, so it could fake or hide one of my custom alarms.
  - The agent can write its own lines to the journal, also with the tags of my scripts (they show its user ID).
  - The agent can create its own cron jobs or user services, but they run only as `claude`.
  - The root-run backup reads the agent's home folder as data, so the agent could fill the backup disk (the script stops at a safety limit and warns).
  - The agent can still use its deploy key and change files in its own home (R7).

## Honest limits and open items

1. **Account takeover (T6).** Whoever controls my Claude account controls this agent. Since 2026-11-15 the agent can no longer become root (R8), but it can still use its deploy key and its allowed commands. This is the main remaining path to the server. **What protects the account today (stated by the owner, 2026-11-16):** login needs a one-time code sent by e-mail, and the e-mail account has two-factor authentication. The Claude account itself has **no** second factor of its own that I can claim, so its security is the security of the e-mail account. Open: a passkey or a second factor on the Claude account itself is being considered, not decided ("maybe").
2. **Persistence by the agent** is limited to its own account (cron jobs and user services as `claude`), because it cannot write files as root.
3. **Backups include the agent's home** (without its credentials file, its program files and the private deploy key). A compromised agent could change the notes file, which the backup then stores.
4. No separate audit log of agent commands, and none is planned for now. The record is the Claude Code transcripts and the system journal.
