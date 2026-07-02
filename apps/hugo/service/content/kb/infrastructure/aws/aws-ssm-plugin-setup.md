---
title: "AWS Session Manager Plugin — Local Setup"
date: 2026-07-01T00:00:00Z
draft: false
description: "How to install the AWS Session Manager plugin locally for SSM shell access and port forwarding."
---

# Local Setup Prerequisites

## AWS Session Manager Plugin

Required for `aws ssm start-session` (both interactive shell access and
port-forwarding sessions) against platform instances. This is a local CLI
plugin, not part of the AWS CLI itself, and it is **not** committed to this
repo — install it once per machine:

```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

Verify:

```bash
session-manager-plugin
```

Should print a version/usage message, not "command not found."

(For non-Ubuntu/WSL environments, see the official AWS docs for the
appropriate package: Session Manager Plugin installation instructions.)
