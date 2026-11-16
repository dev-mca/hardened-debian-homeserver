# 04 - Network access (UFW, Tailscale)

Pattern: **Threat (ID) → Solution → Configuration → How verified**.
All IP addresses in this repository are anonymized: the LAN is shown as `192.0.2.0/24`, the server as `192.0.2.10`, the router as `192.0.2.1`.

## N1 - Default deny on the host

- **Threat:** T2, T1
- **Solution:** UFW blocks all incoming traffic by default. Only TCP 25565 (Minecraft) is allowed from the internet. All other services are reachable from the LAN and the VPN only.
- **Configuration:** The rule set is not published in this repository.
- **How verified:** Verified 2026-11-12 by reading the firewall state: default deny for incoming and routed traffic, and the rules match the statement above. A rule that allowed SSH from anywhere was removed during the audit.

## N2 - Docker ports are filtered too

- **Threat:** T2
- **Solution:** Docker publishes ports through its own iptables chains and bypasses the normal UFW input rules. A custom block in the `DOCKER-USER` chain applies the same policy to published container ports: only the game port is open to the internet, everything else is limited to the LAN and the VPN, and the rest is dropped and logged.
- **Configuration:** The rules are not published in this repository. A newly published container port needs its own entry in this block.
- **How verified:** The block was read on 2026-11-12. The public/LAN split was measured on 2026-11-11 from a LAN device (the web ports answered). The 2026-11-11 outside check used a public scan database (only 25565 known). **External scan, 2026-11-16,** run by the owner from a mobile network (Termux, nmap, TCP connect scan, `-Pn -p 1-30000 --open -T4 --max-retries 1`, 3890 s). The resolved address matched the owner's public IP. Result: `25565/tcp` open (Minecraft). nmap reported the other 29,999 scanned TCP ports as filtered (no response), i.e. none of them open. **Limits:** the scan covers TCP ports 1-30000 only. TCP ports above 30000, UDP, and the view from inside the LAN were not covered. UPnP is enabled on the router (see [N3](#n3---no-port-forwarding-except-the-game-port)), so this is a **point-in-time** result: a device in the LAN can open a port later. The owner repeats the scan from time to time. This scan, not the forwarding table, is the evidence for what is exposed. A scan from a LAN device and a UDP scan are planned. I did not scan from the server.

## N3 - No port forwarding except the game port

- **Threat:** T2, T1
- **Solution:** The router has one manual forward: TCP 25565 to the server. Everything else is reached through Tailscale or from the LAN.
- **Configuration:** In the router (outside the server). The router has a DHCP reservation for the server.
- **How verified:** Checked by the owner in the router on 2026-11-15: one manual forward, TCP 25565 to the server. I did not see the router myself.
- **Known limit, UPnP:** UPnP is **enabled** on the family router, on purpose, because other household devices need it. The router is not under my control. The forwarding table therefore does not prove what is reachable from the internet: any device in the LAN can ask the router to open a port, also towards this server. Exposure is checked by an external scan instead (see [N2](#n2---docker-ports-are-filtered-too)). My earlier note that the router did not answer UPnP requests came from a probe from the server only and is not a reliable statement, so I removed it.
- **What limits the damage (read from the firewall rules, not tested with a real UPnP mapping):** The host firewall and the `DOCKER-USER` block allow all services except the game port only from LAN and Tailscale source addresses. Traffic that arrives from the internet through a UPnP mapping carries a public source address and would be dropped. Only 25565 is allowed from everywhere.

## N4 - Tailscale for remote access

- **Threat:** T1, T2 (no public SSH or web UIs). New threat: T5.
- **Solution:** Remote administration and access to the cloud storage go through a Tailscale tunnel. Tailscale SSH is off. The server advertises a single route (its own LAN address as a /32) so that LAN-style links also work remotely. No exit node. Tailscale Serve and Funnel are not used.
- **Configuration:** Package from the Tailscale repository (updated by unattended-upgrades). Node names and the tailnet name are shown as `<HOST>` and `<TAILNET>`. In the admin console: login through GitHub as identity provider (the GitHub account has two-factor authentication), device approval on, key expiry disabled for the server (accepted on purpose, so it never drops out of the tailnet; if the server is stolen, its node must be removed in the admin console) and 180 days on the phone, Tailscale SSH not enabled, split DNS for the internal name pointing to the server. The advertised /32 route is approved. It covers the server's own address only, not the home LAN.
- **How verified:** Verified 2026-11-12: `tailscale debug prefs` shows `RunSSH: false`, `ShieldsUp: false`, `RouteAll: false`, no exit node, one advertised route (the server's own address as /32). `tailscale serve status` reports no serve config. On that day `tailscale status` showed the server and one more device (a phone). Admin console, checked by the owner on 2026-11-16: three devices (the server, the owner's phone and the owner's laptop, all the owner's), no unknown devices, device approval on, GitHub login with two-factor authentication, ACLs on the default (allow all). I did not see the console myself. The approved route and the key expiry of the server match `tailscale status` on the server.
- **Known limit (T5):** UFW allows all ports on `tailscale0`. A compromised phone or laptop, or any other stolen tailnet device, therefore reaches every service of the server. The subnet route is a /32 to the server only, so a compromised device does not reach the rest of the home LAN through it. Possible hardening, not done: tailnet ACLs that limit the phone to the ports it needs, or a narrower UFW rule.

## N5 - Cloud storage and proxy only for the LAN and Tailscale

- **Threat:** T2, T4
- **Solution:** The reverse proxy returns 403 for the internal cloud name when the client is not in the LAN or Tailscale range. The firewall limits the web ports to the LAN as well, so there are two layers.
- **Configuration:** [`configs/docker-compose/npm-custom-nginx.conf`](../configs/docker-compose/npm-custom-nginx.conf).
- **How verified:** The snippets were read on 2026-11-12. A 403 test from outside is not possible because the ports are closed there. Host-local requests also get 403 (the source is the Docker gateway), so tests must run from a LAN device.
- **Known limit (T4):** Every device in the family LAN can reach these services. No guest or IoT segment exists, and the router is not under my control. Mitigations in place: SSH key-only, strong passwords for the admin UIs, the oCIS login.

## N6 - DNS (Pi-hole)

- **Threat:** T2, T8
- **Solution:** Pi-hole answers only LAN and Tailscale clients (firewall), and the web UI needs a login.
- **How verified:** Verified 2026-11-12 in the compose file. The login requirement of the API comes from my 2026-11-11 audit notes.
- **Change control:** DNS is shared with the family, so updates are applied manually and with care.

## N7 - Wi-Fi instead of Ethernet

- **Threat:** T10
- **Solution:** None. The server uses Wi-Fi (the Ethernet port exists but is unused). In my measurements from 2026-10-30 to 2026-11-01 there were short outages (a few seconds to 30 s). I decided to stay on Wi-Fi.
- **How verified:** Verified 2026-11-12 with `ip -br link`: Wi-Fi interface up, Ethernet interface down.
- **Mitigation:** Push messages that cannot be sent are queued and re-sent later (see [08](08-monitoring-logging.md)).
