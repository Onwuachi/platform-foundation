---
title: "KB-WEB-001: CloudFront + S3 + Hugo — Directory Path 403 Errors"
date: 2026-06-23
description: "Root cause and fix for a CloudFront + private S3 + Hugo setup where the homepage works but every sub-path (/projects/, /resume/, etc) returns 403 instead of the expected page."
tags: ["cloudfront", "s3", "hugo", "terraform", "aws", "troubleshooting"]
categories: ["kb"]
summary: "Homepage worked, every sub-path returned 403. Root cause: default_root_object only covers the bucket root — fixed with a CloudFront Function that rewrites directory paths to index.html."
---
# KB-WEB-001: CloudFront + S3 + Hugo — Directory Path 403 Errors

**Date:** June 23, 2026
**Status:** Root cause identified and fixed
**Applies to:** onwua.com portfolio (Hugo → S3 → CloudFront)

---

## Where this file lives

```
platform-foundation/
└── apps/hugo/service/content/kb/cloudfront-directory-paths.md
```

---

## Symptom

`https://onwua.com/` returns `200 OK`.
`https://onwua.com/projects/` (or any other sub-path) returns `403 AccessDenied`.

The S3 object at the correct key (`projects/index.html`) verifiably exists,
has correct permissions, correct ownership, and is the latest version. The
CloudFront distribution, OAC, and bucket policy are all correctly configured.

This is confusing because every individual piece of the chain checks out —
the bug is in how the pieces interact, not in any single piece being broken.

---

## The full request path

```
Browser
  │  GET onwua.com/projects/
  ▼
Route53 (alias A record)
  │  resolves to CloudFront distribution
  ▼
CloudFront distribution (E127HW59AHJWZG)
  │  checks cache, then forwards to origin
  ▼
Origin Access Control (OAC)
  │  signs the request as CloudFront itself
  ▼
S3 bucket policy check
  │  validates signature + SourceArn match
  ▼
S3 object lookup
  │  ← THIS is where it actually breaks
```

---

## Root cause

`default_root_object = "index.html"` on a CloudFront distribution **only
applies to the bucket root** (`/` → `index.html`). It does **not** apply to
sub-paths.

When a Hugo site builds, a page at `/projects/` is written to disk as:

```
public/projects/index.html
```

Which gets synced to S3 as the object key:

```
projects/index.html
```

But when a browser requests `https://onwua.com/projects/`, CloudFront passes
the literal path through to S3 as the object key:

```
projects/
```

That key **does not exist** in S3 — there is no file there, only the nested
key `projects/index.html`. S3 returns 404 for the missing key, but because
the bucket is private and accessed via OAC, CloudFront/S3 surfaces this as a
`403 AccessDenied` rather than a clean `404 NotFound`. This is what made the
bug look like a permissions problem when it was actually a path resolution
problem.

**Confirmed via:**
```bash
aws s3api head-object --bucket onwua-portfolio-site --key projects/
# → 404 Not Found

aws s3api head-object --bucket onwua-portfolio-site --key projects/index.html
# → 200 OK, object exists
```

---

## The fix

A **CloudFront Function** running on the `viewer-request` event, which
rewrites any request path ending in `/` (or with no file extension) to
append `index.html` before CloudFront looks it up in S3.

```javascript
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    else if (!uri.includes('.', uri.lastIndexOf('/'))) {
        request.uri += '/index.html';
    }

    return request;
}
```

Terraform resource:
```hcl
resource "aws_cloudfront_function" "index_rewrite" {
  name    = "onwua-portfolio-index-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory paths to index.html for Hugo clean URLs"
  publish = true
  code    = file("${path.module}/index-rewrite.js")
}
```

Attached to the distribution's `default_cache_behavior`:
```hcl
function_association {
  event_type   = "viewer-request"
  function_arn = aws_cloudfront_function.index_rewrite.arn
}
```

CloudFront Functions are lightweight JS that run at the edge before cache
lookup — they deploy in ~1 minute, unlike full distribution config changes
which historically took up to 15 minutes to propagate globally.

---

## Why this wasn't caught earlier

The homepage (`/`) worked from day one because `default_root_object`
explicitly covers that one case. Every test done during initial setup
happened to test the root path, so the gap in subdirectory handling stayed
invisible until a second page (`/projects/`) was added.

**Lesson:** when validating a new static site behind CloudFront, test at
least one nested path (`/anything/`), not just the root — `default_root_object`
gives a false sense that "directory index" handling is solved everywhere
when it's actually only solved at `/`.

---

## Diagnostic steps that isolated this (for future debugging)

In order, ruling out one layer at a time:

```bash
# 1. Confirm S3 has the right content (bypasses CloudFront/OAC entirely)
aws s3 cp s3://onwua-portfolio-site/projects/index.html - | grep "expected text"

# 2. Check CloudFront invalidation history — rule out stale cache
aws cloudfront list-invalidations --distribution-id <ID>

# 3. Check x-cache header — Hit vs Miss vs Error tells you if CF reached origin
curl -sI https://yourdomain.com/path/ | grep -i x-cache

# 4. Get the actual S3 error body, not just the status code
curl -s https://yourdomain.com/path/
# <Error><Code>AccessDenied</Code>...

# 5. Verify bucket policy SourceArn matches the real distribution ARN
aws s3api get-bucket-policy --bucket <bucket> --query Policy --output text | jq .

# 6. Verify OAC ID on the distribution matches an existing OAC
aws cloudfront get-distribution-config --id <ID> \
  --query 'DistributionConfig.Origins.Items[0].OriginAccessControlId'
aws cloudfront list-origin-access-controls --query 'OriginAccessControlList.Items[*].[Id,Name]'

# 7. Rule out legacy OAI conflicting with OAC
aws cloudfront get-distribution-config --id <ID> \
  --query 'DistributionConfig.Origins.Items[0].S3OriginConfig'
# OriginAccessIdentity should be "" — non-empty means OAI/OAC conflict

# 8. Test the ROOT path — if it works but a sub-path doesn't, suspect
#    default_root_object scope, not permissions
curl -sI https://yourdomain.com/        # if 200
curl -sI https://yourdomain.com/path/   # but this is 403 → directory index bug

# 9. The decisive check — does the literal directory key exist in S3?
aws s3api head-object --bucket <bucket> --key path/
# 404 here + 200 on path/index.html = confirmed directory index gap
```

---

## Related

- This fix applies to **any** static site on S3 + CloudFront with clean URLs
  (Hugo, Jekyll, Next.js static export, etc.) — not specific to this project.
- Once applied, no further per-page Terraform changes are needed — the
  function handles every current and future directory-style path.
