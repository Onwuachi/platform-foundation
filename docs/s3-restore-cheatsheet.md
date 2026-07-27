## Cheatsheet: `platform register` / `.domain` files & why manual S3 edits are sometimes needed

**The command:**
```bash
echo -n "onwuachi.com,www.onwuachi.com" | aws s3 cp - s3://platform-api-services/platform/services/hugo.domain
```

**Why this exists — the chain:**

```
S3: platform/services/<service>.domain   (source of truth)
        ↓ (aws s3 sync --delete, every rehydrate)
Instance: /opt/platform/services/<service>.domain
        ↓ (read by platform-render-haproxy.sh)
/etc/haproxy/domain.map                  (regenerated every rehydrate — never edit directly)
```

`domain.map` on the live instance is **fully disposable** — it gets rebuilt from scratch on every `platform-rehydrate.sh` run (every boot, every AMI swap, every manual `platform rehydrate`). Editing it directly with `tee`/`vim`/etc. works until the next rehydrate, then silently reverts. The only durable fix is upstream, in the `.domain` file in S3.

**Why `hugo.domain` was wrong in the first place:**

`platform register <service> <port> <domain>` writes whatever domain string you pass, verbatim, once. There's no command that *updates* an existing service's domain later — only `register` (overwrites) or `deregister` (deletes). `platform-render-haproxy.sh` supports comma-separated multi-domain values (`IFS=','`), but that support was added *after* `hugo` was originally registered with just `onwuachi.com` — nothing retroactively touched the already-written file.

**When you'd need to run a command like this again:**
- Adding a new subdomain/alias to an already-registered service (`register` again with the full comma list works too — this direct S3 write is the manual equivalent)
- Fixing a `.domain`, `.port`, or any other per-service file that's wrong at the source, rather than patching the symptom on the live box

**The backup gotcha (now confirmed):**
- Daily snapshot job (`platform-state-backup.yml`) runs 07:00 UTC, `aws s3 sync` of the whole `platform-api-services` bucket.
- Any snapshot dated **before** the fix (≤ 2026-07-24) still has the broken `hugo.domain`.
- `platform restore-from-backup <old-date>` does a full `--delete` sync back into primary — it has no idea one file was stale, so it'll silently reintroduce the bug.
- Rule of thumb: **after any `restore-from-backup` to a date before a known fix, re-check the affected `.domain`/`.port`/config file.**
