# 01 - Threat model

This page lists what the server protects, who or what could harm it, and where an attacker could get in.
Every threat has an ID (T1, T2, ...). The other documents refer to these IDs.

## What is protected

| Asset | Why it matters |
|---|---|
| Personal photos and files in the cloud storage (oCIS) | Private and sensitive. Cannot be replaced. |
| Access to the home network | The server sits in the family LAN. A hacked server is a foothold for the rest of the network. |
| The server itself (root access, secrets) | Whoever controls it controls the data, DNS for the house and the remote-access tools. |
| DNS for the household (Pi-hole) | If it fails or is manipulated, everybody at home notices. |
| Backups | The last line of defence. They must be intact and unreadable for others. |
| Secrets (service passwords, push topic, API tokens) | They give access to services and let others read or fake alerts. |

## Who or what is the threat

- Attackers on the internet. Only one port is meant to be open to them: the Minecraft game port 25565.
- A compromised container.
- A compromised device in the family LAN. Several services answer in the LAN, and the family router is outside my control.
- A stolen Tailscale identity or Tailscale device.
- Someone who takes over the Claude account. The remote-control service on the server would then act on their behalf.
- A faulty action by the AI agent that works on the server.
- My own mistakes and configuration drift.
- Hardware failure, power or network outage, and silent failures nobody notices.

## Threats

| ID | Threat | Short description |
|---|---|---|
| T1 | Internet attacker via the Minecraft port | Port 25565 is forwarded from the router and open to everybody. Attacks on the game server, its plugins or the Java runtime. Also port scanners and bots. |
| T2 | Unintended exposure of other services | A service becomes reachable from the internet by mistake: a new router forward, a Docker port that bypasses the firewall, or a service listening on all interfaces. |
| T3 | Compromised container | An attacker gets code execution in a container (for example through a vulnerability in the game server or the reverse proxy) and tries to reach the host or other containers. |
| T4 | Compromised device in the family LAN | A phone, PC or smart device at home is infected or a guest joins the Wi-Fi. The server's services are reachable from the whole LAN. There is no network segment for guests or IoT. UPnP is enabled on the family router on purpose (other household devices), so any device in the LAN can also ask the router to open ports, including towards this server. The router is not under my control. The host firewall limits what such a mapping can reach (see [04 N3](04-network-access.md)). |
| T5 | Tailscale account or device compromise | Tailscale clients can reach all host ports (default allow-all ACL). A stolen tailnet account or device, for example the phone or the laptop, gives broad access to the server, but not to the rest of the home LAN through the route (it covers the server only). The server's key never expires, so a stolen server must be removed from the tailnet by hand. |
| T6 | Takeover of the Claude account | The Claude Code remote-control service runs on the server. Whoever controls the account can give commands to an agent that has a short sudo allowlist (no shell, no root file changes) and a deploy key for one repository. |
| T7 | Faulty AI action | The agent deletes data, breaks the firewall, locks me out, leaks a secret into a file or a repo, or changes a shared service (DNS, cloud) without asking. |
| T8 | Misconfiguration and drift | A wrong firewall rule, a package update that undoes a hardening step, a `:latest` image that changes behaviour, or a secret in plain text in a config file. |
| T9 | Data loss | Disk failure, accidental deletion, ransomware-style damage, fire, water or an electrical surge. The server and the local backup disk sit in the same place. |
| T10 | Silent failure | Power loss, router or Wi-Fi outage, a stopped service or a failed backup that nobody sees. |
| T11 | Theft of the device | The server SSD is not encrypted. **Accepted risk** (see below). |
| T12 | Outdated software | Container images and some packages are updated by hand. Known vulnerabilities can stay open longer than needed. |
| T13 | Secret exposure | Secrets written in plain text (some compose and service config files), or secrets leaking into this public repository. |

### Accepted risk: T11, theft of the device

I accept this risk on purpose. The server SSD (LVM, ext4) is **not** encrypted. Anyone with physical access to the
laptop can read all data on it, including the photos and the stored secrets. The backup SSD is protected by restic
encryption, but its password file lies on the server, so a thief who takes both gets everything.
Disk encryption would need a passphrase at each boot, which does not fit a headless server that must start after a power outage.

No LUKS is planned. The decision stands. The backup SSD is protected by restic encryption, so losing only that disk does not expose the data.

## Attack surface

| Surface | Exposure | Notes |
|---|---|---|
| TCP 25565 (Minecraft) | Internet | Only intended public port. Whitelist, online mode and a current server build reduce risk. See T1. |
| SSH | LAN and VPN only | Key-only, no root login. Not forwarded by the router. See T4, T5. |
| Reverse proxy and its admin UI | LAN and VPN only | See T4. |
| Cloud storage | LAN and VPN only | Self-signed certificate. See T4. |
| Pi-hole DNS and web UI | LAN and VPN only | See T4. |
| Monitoring dashboard (Netdata) | LAN only | |
| Tailscale | Outbound connections, direct peer traffic | All host ports are open to tailnet devices. See T5. |
| Claude Code remote control | Outbound connection to the Claude service | No inbound port. Control happens through the Claude account. See T6. |
| Docker socket | Local, root-only | Not shared with any container. Only root and the `docker` group can use it. |
| Push alerts (ntfy) and heartbeat (healthchecks.io) | Outbound only | The ntfy topic and the ping URL act like passwords. See T13. |
| Dynamic DNS name | Public DNS record | It points to the home IP address. The name is not published in this repository. |

## Out of scope

- Attacks on the family router and the internet provider.
- Physical attacks beyond theft (T11).
- Targeted attacks by a well-funded attacker.
