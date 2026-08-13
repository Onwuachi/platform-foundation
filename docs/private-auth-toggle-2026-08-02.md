---
title: "Temporarily Opening the Private Area (Toggle Script)"
date: 2026-08-02
description: "How scripts/toggle-private-auth.sh works — commenting out the HAProxy auth directive live via SSM, config-checked before reload, with zero Terraform/git changes."
tags: ["haproxy", "ssm", "security"]
categories: ["infrastructure"]
summary: "Built and confirmed working end-to-end: a reversible way to open /private, /family, and /secure for guests without touching version-controlled config, self-healing back to secured on the next rehydrate."
---

## Problem

`/private`, `/family`, and `/secure` are gated behind HTTP Basic Auth at the HAProxy layer. For a one-off situation (people visiting, wanting to show them something) there was no quick way to open access without either sharing the real password or editing infrastructure-as-code for what's explicitly a temporary, non-recurring need.

## How the gate actually works

One line in `haproxy.cfg`, generated from `infra/packer/ops/scripts/install_haproxy.sh`:

```
acl is_private path_beg  /private /family /secure
http-request auth realm "Onwuachi Private" if is_private !{ http_auth(private_users) }
```

The second line is the entire mechanism: if the request path matches `is_private` and doesn't carry valid credentials against the `private_users` list, HAProxy responds with a `401` and a browser auth prompt. Nothing else in the config participates in this behavior.

## Approach

`scripts/toggle-private-auth.sh disable|enable` — reuses the same `aws ssm send-command` pattern as `manage-web.sh` (target by `tag:Name=ops-01`, no new IAM needed, `github-oidc-role` already has the necessary SSM permissions):

1. `sed -i` comments out (or uncomments) that one `http-request auth realm` line in the live `/etc/haproxy/haproxy.cfg` on the instance
2. `haproxy -c -f ...` dry-run validates the edited config *before* anything is applied — if the edit somehow broke the syntax, this catches it and the reload step never runs, leaving the last-known-good config live
3. `systemctl reload haproxy` — a graceful reload (new process picks up new config, old one finishes in-flight requests, then swaps) rather than a restart, so no dropped connections

Deliberately **not** committed to Terraform/`install_haproxy.sh` itself — this is a live, on-box, temporary edit only. That has a useful side effect: since the AMI's source template is untouched, any future `platform rehydrate` or fresh Packer build regenerates the config from scratch with auth intact, regardless of whether `enable` was run. Temporary means temporary, even if forgotten.

## AWS CLI quoting gotcha hit along the way

The first version built the SSM `--parameters` JSON by hand-escaping quotes inside a bash string — the AWS CLI's shorthand parameter parser chokes on nested double quotes even when correctly escaped at the shell level. Fixed by generating the JSON with Python's `json.dumps()` inside the script instead of hand-building it in bash — letting a tool actually designed for JSON encoding handle the escaping, rather than fighting shell quoting rules.

## Result

Confirmed working end-to-end, twice — `disable` (verified via curl returning `200` and a full page load with no auth prompt) and `enable` (verified via curl returning `401` and the browser showing the real auth dialog again). `ensure-sso.sh`, built the day prior for Hugo deploys, transparently caught and recovered an expired SSO token mid-run without any separate manual step.
