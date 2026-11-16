# 08 - Monitoring and logging

Pattern: **Threat (ID) → Solution → Configuration → How verified**.

## M1 - Metrics and dashboard (Netdata)

- **Threat:** T10, T8
- **Solution:** Netdata shows CPU, RAM, disk, network, temperatures, container charts and alarms on a dashboard in the LAN. A spare phone shows a small status page (a one-page kiosk that reads the Netdata API). Details are not part of this repository.
- **Configuration:** [`configs/netdata/netdata.conf`](../configs/netdata/netdata.conf), [`configs/netdata/health-mca.conf`](../configs/netdata/health-mca.conf).
- **How verified:** Verified 2026-11-12: the service runs. See also [05 S7](05-services.md).

## M2 - Hardware watcher and push alerts

- **Threat:** T10
- **Solution:** `mca-hw-watch` (a systemd service) watches mains power, battery, CPU temperature and the router. It reports through `mca-alert`:
  - **Journal:** always (tag `mca-alert`).
  - **Push to my phone** (ntfy): every level except `info`. Messages that cannot be delivered (for example during a Wi-Fi outage) wait in a short-lived queue and are sent later.
  - **Sound on the laptop speaker:** only for critical events (a very high CPU temperature, a nearly empty battery, a long power outage), and never at night.
  - A power outage is only reported after a short delay (brief unplugging stays silent).
- **Configuration:** [`scripts/mca-alert`](../scripts/mca-alert), [`scripts/mca-hw-watch`](../scripts/mca-hw-watch), [`configs/systemd/mca-hw-watch.service`](../configs/systemd/mca-hw-watch.service), settings example [`configs/alert/mca-alert.env.example`](../configs/alert/mca-alert.env.example).
- **Secret handling:** The ntfy topic is the only protection of the push channel, so it is treated like a password (stored in a root-only file, never in this repo). ntfy.sh can read the message text, so messages contain only short keywords such as "power outage" or "backup failed", no private details.
- **How verified:** Verified 2026-11-12: the service is active and enabled. Tests from 2026-11-02 (my notes): the decision logic in a dry-run mode, delivery and queueing against a local test server, the watcher with dummy inputs, and three real test messages that arrived on my phone. A real power outage was tested once with the plug on 2026-11-01 (before the push channel existed). A real long outage was never tested.

## M3 - Dead man's switch (healthchecks.io)

- **Threat:** T10 (the server, router, Wi-Fi, power or internet fails, so it cannot send anything itself)
- **Solution:** The watcher pings a healthchecks.io URL regularly. If pings stop, healthchecks.io sends the alert from outside.
- **Configuration:** The ping URL is a secret and lives in a root-only settings file. The check is set up with a short period and a short grace time, and with a notification through ntfy.
- **How verified:** A manual ping returns HTTP 200 (notes). **The alert for missing pings was never tested**. Whether the notification is set up in the check was reported by the owner and is not verified by me. The test is planned.

## M4 - Netdata alarms

- **Threat:** T10
- **Solution:** Custom alarms: on battery, CPU temperature, Wi-Fi interface down, backup age. The first three are set to `silent`, because `mca-alert` already sends the push. Only the backup-age alarm and critical default alarms go out through a custom sender (critical and its recovery only).
- **How verified:** Read 2026-11-12. All alarms were in "clear" state on 2026-11-02 (notes).

## M5 - Alert muting

- **Threat:** T7, T10
- **Solution (in progress):** Alert muting is being reworked. The intended rule is that muting only affects local signals (the laptop speaker and the phone dashboard) and that push messages are always sent.
- **How verified:** Not verified. This describes the intended behaviour, not a tested one.

## M6 - Logging

- **Threat:** T1, T4, T7
- **Solution:** The default systemd journal, UFW logging at the "low" level, and the DOCKER-USER block logs dropped packets (rate-limited). The agent can read the system journal only through `sudo`.
- **How verified:** Verified 2026-11-12: UFW logging "on (low)". Rate and noise of the logs from my notes: most DOCKER-USER drops come from the router itself.
- **Gaps (from the Lynis baseline):** No remote log host (LOGG-2154), no `auditd`, no file integrity tool, no process accounting. No alerts for security events such as failed SSH logins, changes in `sudoers`, `authorized_keys` or firewall rules, or unexpected containers. Planned, not implemented.

## M7 - Notification channels (what leaves the server)

| Channel | Content | Destination |
|---|---|---|
| ntfy push | Short alert text | ntfy.sh (public service, secret topic) |
| Heartbeat | An empty HTTP request | healthchecks.io |
| Tailscale | Tunnel traffic (encrypted) | Tailscale coordination and peers |
| Claude Code | Session traffic | Claude service |
| Dynamic DNS | The current public IP address | DuckDNS |
| Netdata | Nothing (not connected to Netdata Cloud, no anonymous statistics) | - |
