---
title: "KB-NET-001: Docker Networking, Port Mapping, and SSM Port Forwarding"
date: 2026-06-24
description: "How Docker bridge networking, --network host, container port mapping, environment variables (-e), and AWS SSM port forwarding actually work — and why mixing networking modes between containers caused a real bug in this platform."
tags: ["docker", "networking", "ssm", "aws", "grafana", "prometheus", "troubleshooting"]
categories: ["kb"]
summary: "Two layers of networking stacked on top of each other — Docker container networking on the EC2 host, and SSM port forwarding from your laptop to that host — and why a container networking mismatch between Prometheus and Grafana caused connection refused even though everything looked fine."
---

# KB-NET-001: Docker Networking, Port Mapping, and SSM Port Forwarding

**Date:** June 24, 2026
**Status:** Root cause identified and fixed
**Applies to:** Grafana/Prometheus on the platform-foundation EC2 instance

---

## There are TWO separate networking layers here

This is the most important thing to internalize before any of the rest
makes sense. You're crossing two completely independent networking
boundaries every time you load a Grafana dashboard from your laptop:

```
Layer 1: Your laptop  ->  EC2 instance        (SSM port forwarding)
Layer 2: Inside EC2:  container  ->  container (Docker networking)
```

These are unrelated mechanisms solving different problems. Confusing them
is exactly what made this bug hard to reason about at first.

---

## Layer 1: SSM Port Forwarding (laptop to EC2)

Your EC2 instance has no public SSH access and no open ports for
direct connections — that's intentional, per the platform's security model
(SSM Session Manager only, no bastion, no SSH keys). So how do you ever
reach localhost:4000 in your browser if Grafana is running on a server
in AWS, not on your laptop?

```bash
aws ssm start-session \
  --target i-058a806b942b92290 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["4000"],"localPortNumber":["4000"]}'
```

This creates an encrypted tunnel through AWS's own infrastructure (not
the public internet, not your VPC's normal networking) directly to the SSM
agent running on the instance. Once this command is running:

```
Your browser -> localhost:4000 (on YOUR laptop)
                    |
                    v
            SSM tunnel (via AWS API, authenticated by your IAM creds)
                    |
                    v
            EC2 instance's localhost:4000
                    |
                    v
            Whatever is actually listening on port 4000 there
```

Key facts:
- portNumber = the port on the remote instance you want to reach
- localPortNumber = the port on your laptop you'll actually connect to
- These don't have to match, though we kept them the same for clarity
  (forwarding remote 9090 to local 9090, remote 4000 to local 4000)
- The tunnel only exists while that terminal command is running — close it,
  and localhost:4000 on your laptop stops working until you reopen it
- This is why you need two separate tunnels (two terminal windows) to
  reach both Prometheus (9090) and Grafana (4000) at the same time — one
  tunnel forwards exactly one port

This layer was never the problem. It worked correctly throughout this
entire debugging session.

---

## Layer 2: Docker Container Networking (container to container, on the EC2 host itself)

This is where the actual bug lived. Once your SSM tunnel gets you onto the
EC2 host's port 4000, you're talking to the Grafana container. But
Grafana itself, running inside that container, needs to reach Prometheus
— and that's an entirely separate hop that has nothing to do with SSM.

### Default Docker networking (bridge mode)

By default, every docker run creates a container on an isolated virtual
network called the bridge. Containers on this bridge get their own
private IP space (commonly 172.17.0.0/16) completely separate from the
host's real network interfaces.

```
EC2 Host
 +- real interface: 127.0.0.1 (host loopback)
 |
 +- docker0 bridge: 172.17.0.0/16 (virtual, isolated)
      +- grafana container:  172.17.0.3
      +- (other bridge containers get their own 172.17.x.x IP)
```

The critical consequence: inside a bridge-networked container,
localhost refers to the container itself, not the host machine. If
Grafana's container tries to reach http://localhost:9090, it's asking
"is anything listening on port 9090 inside MY OWN container" — and nothing
is, because Prometheus runs in a different container (or, after our
earlier fix, directly using the host's network).

This produces exactly the error we saw:
```
dial tcp [::1]:9090: connect: connection refused
```
[::1] is the IPv6 form of localhost — Grafana correctly tried to
connect to "localhost," it just had the wrong idea of what localhost
meant from inside its own isolated network namespace.

### --network host — opting out of the bridge entirely

```bash
docker run --network host ...
```

This tells Docker: don't create an isolated network namespace for this
container at all — let it share the host's actual network stack directly.
With this flag, localhost inside the container is the same
localhost as the EC2 host itself. No bridge, no translation, no
172.17.x.x virtual IP.

This is why Prometheus reaching 127.0.0.1:9100 (node exporter),
127.0.0.1:8404 (HAProxy stats), and 127.0.0.1:9115 (blackbox exporter)
all worked once we added --network host to prometheus.service — every
one of those services is bound to the host's real loopback interface, and
host networking is what let Prometheus's container see them as "localhost"
too.

Grafana was still on bridge mode the whole time this session — it had
the provisioning mounts fixed, the datasource configured, the dashboard
variable fixed — but the underlying network path to reach Prometheus was
still broken, because grafana.service never got the same --network host
treatment prometheus.service did. Two services, two different networking
modes, talking to each other — one fix from weeks ago didn't get applied
consistently to its sibling service.

### Why -p host:container port mapping existed before

Before the fix, grafana.service had:
```
-p 127.0.0.1:4000:3000
```

This is the bridge-mode way of exposing a container port to the host.
Reading it right-to-left: take whatever is listening on port 3000 inside
the container, and make it reachable at 127.0.0.1:4000 on the host.
This is necessary specifically because bridge-networked containers are
otherwise invisible from the host — you have to explicitly punch a hole
for each port you want reachable.

Once you switch to --network host, this entire concept disappears —
there's no longer a separate container network to punch a hole through.
The container just binds directly to a host port, like any other normal
process would. That's also why removing -p 127.0.0.1:4000:3000 was
required, not optional, when adding --network host — -p mappings have
no effect at all in host networking mode and Docker will silently ignore
them (or in some versions, error).

---

## The new piece: -e GF_SERVER_HTTP_PORT=4000

Here's the subtlety that made the host-networking fix slightly more than
a one-line change.

Grafana's Docker image is built to listen on port 3000 by default —
that's baked into the image itself, not something docker run flags
control directly. In bridge mode, this didn't matter: Grafana happily
listened on 3000 inside its isolated bridge network, and the -p
127.0.0.1:4000:3000 mapping did the work of presenting that as port 4000
on the host.

With --network host, there's no mapping layer anymore — Grafana would
bind directly to port 3000 on the actual host, not 4000. That's a
real collision: platform-api already owns 127.0.0.1:3000 on this host.
Two processes can't bind the same port.

The fix: Grafana reads an environment variable, GF_SERVER_HTTP_PORT, at
startup to decide which port to actually listen on. -e is the standard
Docker flag for injecting an environment variable into a container:

```bash
docker run -e GF_SERVER_HTTP_PORT=4000 ...
```

This tells Grafana itself — not Docker, not the network layer — "listen
on 4000, not your default of 3000." Now Grafana binds directly to
127.0.0.1:4000 on the host (via host networking), with no collision and
no port-mapping translation needed.

General pattern worth remembering: when you can't use -p to remap a
port (because you're in --network host mode), check if the application
itself has a config option or environment variable to change its listen
port directly. Almost every well-behaved containerized service does.

---

## The full corrected grafana.service

```ini
[Unit]
Description=Grafana
Requires=docker.service network-online.target
After=docker.service
Wants=network-online.target

[Service]
ExecStartPre=-/usr/bin/docker rm -f grafana
ExecStart=/usr/bin/docker run \
  --name grafana \
  --network host \
  -e GF_SERVER_HTTP_PORT=4000 \
  -v /opt/grafana/data:/var/lib/grafana \
  -v /etc/grafana/provisioning:/etc/grafana/provisioning:ro \
  -v /opt/grafana/dashboards:/opt/grafana/dashboards:ro \
  grafana/grafana:10.4.2

ExecStop=/usr/bin/docker stop grafana
Restart=always
RestartSec=5

[Install]
WantedBy=ops.target
```

Compare against prometheus.service — same --network host pattern,
same volume-mount style. The two services are now consistent with each
other.

---

## Diagnostic technique that found the real error

Grafana's dashboard panels showing generic "No data" told us nothing
useful on their own. The actual breakthrough came from using Grafana's
built-in panel inspector:

1. Hover over any panel showing "No data"
2. Click the panel's options menu (or the small icon that appears)
3. Select Inspect -> Panel
4. Click the Error tab

This revealed the real HTTP-level error (502, connection refused)
instead of the generic UI message. This technique generalizes: any
time a Grafana panel shows "No data" with no further explanation, the
panel inspector's Error tab is the first place to look — it shows you
exactly what query failed and why, rather than guessing.

---

## Sequence of fixes that got us here (for the record)

1. Fixed malformed prometheus.yml (orphaned ec2_sd_configs block)
2. Added --network host to prometheus.service — fixed node_exporter,
   HAProxy metrics, and blackbox exporter scraping
3. Fixed HAProxy's /metrics endpoint via frontend stats block
4. Fixed Grafana's provisioning mounts (/etc/grafana/provisioning,
   /opt/grafana/dashboards) — datasource started auto-provisioning
5. Imported Node Exporter Full dashboard (ID 1860) — panels showed "No data"
6. Found the dashboard's job template variable had no Label selected —
   fixed by setting Label to job
7. This fix: discovered Grafana itself was still on bridge networking
   while Prometheus had already moved to host networking — added
   --network host plus -e GF_SERVER_HTTP_PORT=4000 to grafana.service

Each fix was necessary but not sufficient on its own — this is a good
example of how a single visible symptom ("No data") can have multiple
independent root causes stacked on top of each other (config parsing,
provisioning mounts, dashboard variables, container networking), each
needing to be resolved before the next one becomes visible.
