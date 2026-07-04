---
title: "KB-OBS-001: Grafana Dashboards Vanish After Reset"
date: 2026-07-04
description: "Why UI-imported Grafana dashboards are not durable, and how to provision them as files so they survive database resets and AMI rebuilds."
tags: ["grafana", "prometheus", "observability", "docker", "provisioning"]
categories: ["infrastructure"]
summary: "UI-imported dashboards live only in Grafana's SQLite database and disappear if it resets. File-based provisioning fixes this permanently."
---

## Symptom

Grafana prompts for a mandatory password reset on login (a sign it has reset to
factory defaults). Hitting the API confirms it:

```bash
curl -s -u admin:admin http://localhost:4000/api/search
# []
```

Dashboards that were previously working — Node Exporter Full, HAProxy, Prometheus
2.0 Overview — are gone. Datasources, however, may still be present.

## Root Cause

Grafana persists two very different kinds of state, and they are **not** equally
durable:

| State type          | Where it lives                          | Survives DB reset? |
|----------------------|------------------------------------------|---------------------|
| UI-imported dashboard | `grafana.db` (SQLite) only               | ❌ No |
| File-provisioned dashboard | JSON file on disk, referenced by `dashboards.yml` | ✅ Yes |
| File-provisioned datasource | YAML file on disk (`datasources/*.yml`) | ✅ Yes |

If a dashboard was added via **Dashboards → New → Import → (enter grafana.com ID)**,
it is written *only* to `grafana.db`. If that database is ever reset — via a
container recreate without a persistent volume, an accidental `rm`, a corrupted
SQLite file, or any other reset event — the dashboard is gone with no way to
recover it short of re-importing.

Datasources set up via a provisioning YAML file (e.g.
`/etc/grafana/provisioning/datasources/datasource.yml`) do **not** have this
problem, because Grafana re-reads and re-creates them from the file on every
startup, regardless of what's in the database. You can confirm a datasource was
provisioned this way if the API reports it as read-only:

```bash
curl -s -u admin:admin http://localhost:4000/api/datasources
# "readOnly": true  <- confirms provisioning, not manual entry
```

## Diagnostic Steps

1. Check Docker mounts to rule out a missing volume:
```bash
   sudo docker inspect grafana --format '{{json .Mounts}}'
```
2. Check whether the dashboard-provisioning folder actually contains real
   dashboard JSON, or just an empty placeholder:
```bash
   ls -la /opt/grafana/dashboards/
```
3. Check the provisioning configs to confirm what Grafana *should* be
   autoloading on startup:
```bash
   cat /etc/grafana/provisioning/dashboards/dashboards.yml
   cat /etc/grafana/provisioning/datasources/datasource.yml
```
4. Hit the Grafana API directly rather than guessing from file timestamps —
   this is the ground truth of what Grafana currently knows about:
```bash
   curl -s -u admin:admin http://localhost:4000/api/search
   curl -s -u admin:admin http://localhost:4000/api/datasources
```

## Fix

Download the dashboard JSON directly from grafana.com and drop it into the
folder your `dashboards.yml` provider already points at:

```bash
cd /opt/grafana/dashboards

sudo curl -s https://grafana.com/api/dashboards/1860/revisions/37/download \
  -o node-exporter-full.json

sudo curl -s https://grafana.com/api/dashboards/3662/revisions/2/download \
  -o prometheus-stats.json

sudo curl -s https://grafana.com/api/dashboards/789/revisions/1/download \
  -o haproxy-native.json

# remove any dead placeholder files
sudo rm -f /opt/grafana/dashboards/ops-overview.json

# fix ownership so the grafana container (uid 472) can read them
sudo chown -R 472:472 /opt/grafana/dashboards
```

Grafana's file provider polls for changes automatically (default every 10s), but
a restart guarantees a clean pickup:

```bash
sudo docker restart grafana
```

Verify:

```bash
curl -s -u admin:admin http://localhost:4000/api/search
```

## Prevention

- **Never use "Import via grafana.com ID" through the Grafana UI for anything
  that needs to survive a rebuild.** Always download the JSON and provision it
  as a file instead.
- Any new dashboard should be added to `/opt/grafana/dashboards/` and committed
  to source control (Packer / platform-rehydrate scripts) so a rebuilt AMI
  ships with dashboards already in place.
- When choosing a community dashboard ID, confirm the metric schema matches
  what's actually being scraped. HAProxy has two incompatible conventions:
  the standalone `haproxy_exporter` (older, different metric names) and
  HAProxy's own native Prometheus exporter (`/metrics` on a `stats` frontend,
  HAProxy 2.x+). Dashboard IDs built for one will show "No data" against the
  other even though the datasource and scrape target are both healthy.

## Related

- `KB-NET-001` — Docker bridge vs. host networking with SSM
- Prometheus native HAProxy exporter setup: `frontend stats` block bound to
  `127.0.0.1:8404`, exposed via `http-request use-service prometheus-exporter
  if { path /metrics }`
