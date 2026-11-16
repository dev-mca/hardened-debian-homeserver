# Changelog

This file lists changes to the documentation. It does not replace the system history. For server changes see the notes in each document.

## 2026-11-16

- Pi-hole web password moved to a `.env` file (mode 600) and rotated, compose file mode 600, time zone aligned (confirmed by the owner). Weakness replaced by a before/after entry in docs/03 H5.
- Router checked by the owner on 2026-11-15: one manual forward (TCP 25565). UPnP is enabled on the family router on purpose, so exposure is judged by external scans. Added to docs/04 N3 and to threat T4.
- External TCP scan of ports 1-30000 from a mobile network: 25565/tcp open, the other 29,999 scanned TCP ports filtered (no response). Limits stay visible: ports above 30000, UDP and a LAN scan are not covered, and the result is point-in-time because UPnP is enabled on the router.
- Claude account: login by e-mail code, the e-mail account has 2FA. No own 2FA of the Claude account claimed.
- GitHub ruleset on `main` recorded (no deletion, no force-push, no PR requirement).
- Tailscale admin console checked by the owner (GitHub login with 2FA, three devices (server, phone, laptop), device approval, key expiry, SSH off, /32 route to the server only, default ACL).
- Status list date updated.

## 2026-11-15

- Sudo allowlist for the agent account applied and tested (all 41 allowed test commands work, all 38 tested commands outside the list are refused). It replaces the blanket `NOPASSWD: ALL` rule. New: `configs/sudoers/claude-allowlist` and section R8 in docs/06. Docs 01, 03, 07, 09 and the README updated. The Android debug bridge for the monitoring phone now needs a manual start by the admin.
- Agent settings: the `ufw` permission rule is narrowed to `ufw status`.
- Confirmed in three real snapshots that the private deploy key is not in the backup.

## 2026-11-12

- Repository created. Threat model, architecture, hardening, network, services, remote Claude Code, backup, monitoring.
- Sanitized configs and translated scripts added.
- Lynis and gitleaks installed from the Debian repository on the server. Lynis baseline measured: hardening index 68, 1 warning, 46 suggestions.
- Findings recorded.
- Deploy key for this repository created on the `claude` account (one repo, write access). Documented in docs/06 R7, docs/03 and the README. Earlier statements "no SSH keys" corrected.
- Private deploy key added to the backup exclude list. Verified with restic dry runs. Docs 06 and 07 and the README updated.
