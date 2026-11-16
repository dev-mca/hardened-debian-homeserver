# 09 - Audit results

## Lynis baseline (before)

- Tool: Lynis (Debian package), quick system audit
- Date: 2026-11-12
- Scope: the host only (Lynis does not look inside containers).
- Result: **hardening index 68**, 263 tests, **1 warning**, **46 suggestions**.

Note on timing: This baseline was taken **after** the hardening of 2026-10-30 to 2026-11-11 (firewall, SSH, permissions, updates).
It is therefore the "before" value for the **next** round of measures, not for the whole project. I have no Lynis value from before the earlier hardening.

### Themes and decisions

The raw findings are not published. The suggestions fall into these themes:

- SSH options, brute-force protection and boot-loader hardening.
- Auditing, file integrity and process accounting.
- Package hygiene and update tooling.
- Kernel and network parameters.
- Password policy, banners and partition layout.
- One warning about a time-synchronisation check.

My decisions: brute-force blocking, a boot-loader password and a malware scanner are **not needed** or not planned, for the reasons in [03](03-hardening.md). Some SSH options are being tightened (see the README, "Planned"). The other themes are low value for this setup or not decided yet. The time-synchronisation warning and one file-permission finding will be re-checked in the next run.

## Measures since the baseline

- 2026-11-15: The blanket passwordless sudo of the agent account was replaced by an allowlist of exact commands (see [06 R8](06-remote-claude-code.md)). The Lynis baseline has no finding for this, so no change of the score is expected from this measure.

## Lynis "after" measurement

Not run yet. It follows after the next round of measures.
Measures before the "after" run: the `claude` sudo allowlist is done (2026-11-15). Planned next: SSH forwarding off and a few more small measures. Not decided yet: the remaining suggestions.

| | Baseline 2026-11-12 | After |
|---|---|---|
| Hardening index | 68 | not measured yet |
| Warnings | 1 | |
| Suggestions | 46 | |

## Other checks (not Lynis)

| Date | Check | Result |
|---|---|---|
| 2026-11-11 | Internet-side look at the home IP address with a public scan database | Only the Minecraft port known, no known vulnerabilities (from my notes) |
| 2026-11-11 | Container and package review during my audit | Several services updated. The firewall for the web ports was narrowed to the LAN. |
| 2026-11-16 | External TCP connect scan from a mobile network (nmap in Termux, `-Pn -p 1-30000 --open -T4 --max-retries 1`, 3890 s, run by the owner; the resolved address matched the owner's public IP) | In TCP 1-30000, `25565/tcp` (Minecraft) was the only open port. nmap reported the other 29,999 scanned TCP ports as filtered (no response). **Not covered:** TCP ports above 30000, UDP, the view from inside the LAN. **Point in time:** UPnP is enabled on the router, so the owner repeats the scan from time to time. |
| not done | Port scan from a LAN device, UDP scan from outside | Planned. I did not install or run a scanner on the server. |

### Findings during this documentation round

1. The Pi-hole web password was in a compose file with mode 664. Fixed on 2026-11-15: moved to a `.env` file (mode 600) and rotated (see [03 H5](03-hardening.md)).
