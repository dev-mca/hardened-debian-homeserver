# Scripts

These are sanitized and translated copies of scripts that run on the server.
They are **not byte-identical** to the installed files: comments and messages are in English, real paths and addresses are replaced
(`<USER>` for my admin account, `192.0.2.1` for the router). The logic is the same. I checked only the syntax of the translated copies (`bash -n`), I did not run them.

| Script | Where | Purpose |
|---|---|---|
| `mca-backup` | root-owned script on the server | Nightly restic backup, see [docs/07](../docs/07-backup-restore.md) |
| `mca-alert` | root-owned script on the server | Journal, push (ntfy) and sound alerts, see [docs/08](../docs/08-monitoring-logging.md) |
| `mca-alerts` | root-owned script on the server | Alert muting (being reworked, see docs/08 M5) |
| `mca-hw-watch` | root-owned script on the server | Power, battery, temperature and Wi-Fi watcher |
| `check-secrets.sh` | not installed | Pre-commit check for secrets and private data in this repository |

Not included, because they do not exist: an update-check script and an audit script. Updates and Lynis runs are done by hand.
An update-check script (list pending apt and image updates) is planned for later. Until then the monthly update routine is manual.

The restic password, the ntfy topic and the healthchecks.io URL are **not** part of any script. They live in root-only files on the server.
