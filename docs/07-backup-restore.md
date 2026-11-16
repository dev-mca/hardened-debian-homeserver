# 07 - Backup and restore

Pattern: **Threat (ID) → Solution → Configuration → How verified**.

## B1 - Nightly encrypted backup to an external SSD

- **Threat:** T9 (data loss), T7 (faulty action), T13
- **Solution:** `restic` writes an encrypted, versioned backup to an external USB SSD every night. restic encrypts data and file names (AES-256), so a lost or stolen backup SSD alone reveals nothing.
- **Configuration:**
  - Script: [`scripts/mca-backup`](../scripts/mca-backup). Timer and service: [`configs/systemd/mca-backup.timer`](../configs/systemd/mca-backup.timer), [`mca-backup.service`](../configs/systemd/mca-backup.service). Exclude list: [`configs/backup/mca-backup.exclude`](../configs/backup/mca-backup.exclude).
  - The SSD is mounted through `/etc/fstab` with `nofail`. The empty mount point is protected so that nothing is written to it when the SSD is missing.
  - The repository lives on the SSD. The password is in a root-only file on the server (never in this repository).
  - What is backed up: the Docker stacks (including `.env` files), the oCIS data folder, SSH keys of my admin account, system configuration, my own scripts, Tailscale state, the agent's home (without its Claude credentials, its program files and the private GitHub deploy key, see [06 R7](06-remote-claude-code.md)), and a text snapshot of the system state (container list, firewall, units, package list).
  - The oCIS folder is backed up **while oCIS is stopped for about one second**, so the copy is consistent. A `trap` in the script and `ExecStopPost` in the unit make sure oCIS is started again.
  - The running Minecraft world is not backed up raw. The consistent daily archives of the `minecraft-backup` container (kept for 7 days) are backed up instead.
  - Weekly and on demand: remove old snapshots (daily, weekly, monthly and yearly generations are kept), check a sample of the data, check the SMART status of the SSD.
  - Safety checks before every run: SSD mounted, marker file present, repository readable, enough free space. On errors: journal entry, a push warning, and a failure marker file.
- **How verified:** Verified 2026-11-12: timer enabled, next run 2026-11-13, last successful run 2026-11-12 (`last_success` file), SSD mounted. Script copy compared with the installed file (identical before translation).
- **Disk-encryption decision:** I use restic encryption only, no extra LUKS layer, and none is planned. The restic encryption protects the backup disk. The server disk is not encrypted, so a LUKS key on the server would add no protection and would add a second way to lose the data (damaged LUKS header). The effect: if only the backup SSD is lost, the data is unreadable. If the server **and** the SSD are stolen, the password file is on the server (same situation as the oCIS data itself, see T11).

## B2 - Monitoring of the backup

- **Threat:** T10
- **Solution:** The hardware watcher sends the age of the last successful backup to Netdata. An alarm warns when it is too old and turns critical later. Critical goes out as a push message.
- **Configuration:** [`configs/netdata/health-mca.conf`](../configs/netdata/health-mca.conf).
- **How verified:** Read 2026-11-12. The alarm itself was **not tested** (a real test would let the backup age grow past the limit). Open item.

## B3 - Restore

The archive contains a restore guide on the SSD itself (without the password).

```bash
# Run as root. Use your own mount point and password file.
export RESTIC_REPOSITORY=<MOUNT>/restic
export RESTIC_PASSWORD_FILE=<PASSWORD_FILE>

restic snapshots                                  # list snapshots (tags: ocis, system)
restic ls latest --tag system | head              # look inside
# Restore into an EMPTY folder first, never directly over live data:
mkdir <TEST_DIR> && mount -t tmpfs tmpfs <TEST_DIR>
restic restore latest --tag ocis --target <TEST_DIR> --verify
# Then copy what you need to its place. Stop the affected container before you replace its data.
```

Use a tmpfs for tests: a test folder with plain-text keys on the (unencrypted) SSD would be a leak, and the agent has no `rm` through sudo.

- **How verified:** A restore test was done once on 2026-11-01 (from my notes): restore with `--verify` into a tmpfs, 168 of 168 files, owner and modes kept, `restic check --read-data` without errors. **No regular restore test exists yet.** Decision: a manual restore test every quarter. The first quarterly test has not been done.

## B4 - Limits (honest)

| Limit | Effect | Status |
|---|---|---|
| Server and backup SSD are in the same place and on the same power | Fire, water, theft or an electrical surge can destroy both | **Open.** No off-site copy yet. Rule: do not delete the original photos until one exists. The option for the off-site copy is not chosen yet. |
| Backup password is only on the server | Without a copy of the password, the backups are lost | I noted the password in my password manager (from my notes). Not re-checked. |
| No versioning inside oCIS | A deleted file is only recoverable from the nightly backup | Accepted |
| The backup runs as root and its script is root-owned | The old blanket sudo of the agent could have edited it | Fixed 2026-11-15: the agent has no root file access to the script or its folder (see [06 R8](06-remote-claude-code.md)) |
| Pi-hole and Nginx Proxy Manager SQLite files are copied live | A rare inconsistent copy is possible | Accepted, both can be rebuilt |
| No append-only or offline copy | Ransomware with root access could delete the backups too | Open |
