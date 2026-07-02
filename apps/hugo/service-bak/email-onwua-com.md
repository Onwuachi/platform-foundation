# KB: Email Setup — derrick@onwua.com

**Date:** June 14, 2026  
**Status:** ✅ Complete and verified

---

## Where this file lives

```
platform-foundation/
└── apps/hugo/service/content/kb/email-onwua-com.md
```

This is a KB article for the self-hosted Hugo platform at onwuachi.com.  
It documents the email forwarding setup for the portfolio domain onwua.com.

---

## Overview

Email forwarding for `@onwua.com` using ImprovMX free tier.  
No mail server. No paid service. Forwards to Gmail.

```
sender → derrick@onwua.com
              │
              ▼
       mx1.improvmx.com
              │
              ▼
       onwuabus@gmail.com
```

**Verified working:** SPF ✅ · DKIM ✅ · DMARC ✅

---

## Components

| Component | Provider | Cost |
|---|---|---|
| MX records | Route53 (onwua.com hosted zone) | included in $0.50/mo zone |
| Email forwarding | ImprovMX free tier | $0 |
| Inbox | Gmail (onwuabus@gmail.com) | $0 |

---

## DNS Records — Route53 (onwua.com)

Added to hosted zone `Z03022483OP7X6M16F4GW`:

```
Type: MX
Name: onwua.com
TTL:  300
Values:
  10 mx1.improvmx.com
  20 mx2.improvmx.com
```

**Command used:**
```bash
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name onwua.com \
  --query 'HostedZones[?Name==`onwua.com.`].Id' \
  --output text | cut -d'/' -f3)

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "onwua.com",
        "Type": "MX",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "10 mx1.improvmx.com"},
          {"Value": "20 mx2.improvmx.com"}
        ]
      }
    }]
  }'
```

**Verify records are live:**
```bash
dig MX onwua.com +short
# Expected:
# 10 mx1.improvmx.com.
# 20 mx2.improvmx.com.
```

---

## ImprovMX Setup

- **Account:** onwuabus@gmail.com
- **Domain:** onwua.com
- **Alias:** `*@onwua.com` (catch-all) → `onwuabus@gmail.com`
- **Dashboard:** https://app.improvmx.com

Catch-all means any address at `@onwua.com` routes to Gmail —  
`derrick@onwua.com`, `hello@onwua.com`, anything.

---

## Gmail Filter (Recommended)

To identify emails arriving via onwua.com in your Gmail inbox:

1. Gmail → Settings → See all settings → Filters and Blocked Addresses
2. Create new filter
3. **To:** `derrick@onwua.com`
4. Apply label: `onwua.com`
5. Create filter

This tags any email sent to your portfolio address so you can identify it at a glance.

---

## How to identify forwarded email

Forwarded email shows the **original sender** in your inbox, not the `@onwua.com` address.  
To confirm routing, view raw headers:

Gmail → open email → three dots (⋮) → **Show original**

Look for:
```
Delivered-To: derrick@onwua.com        ← confirms it came via onwua.com
X-Forwarding-Service: ImprovMX v3.0.0  ← confirms ImprovMX handled it
```

---

## Send As (Optional — not yet configured)

To reply from `derrick@onwua.com` inside Gmail, ImprovMX requires a **paid plan** ($9/mo) for SMTP.

Alternative (free): Use Gmail "Send mail as" with a free SMTP relay like Brevo or Mailjet.

Steps when ready:
1. Sign up for Brevo free tier (300 emails/day free)
2. Gmail → Settings → Accounts → Send mail as → Add address
3. SMTP: `smtp-relay.brevo.com` · Port: `587`
4. Verify ownership via confirmation email

---

## Open Items

- [ ] Set up Gmail filter to label onwua.com emails
- [ ] Configure Send As if replying from derrick@onwua.com becomes needed

---

## Verification Test

**Sent:** `donwuachi@yahoo.com` → `donwuachi@onwua.com`  
**Result:** Delivered to `onwuabus@gmail.com` ✅  
**Auth:** SPF pass · DKIM pass · DMARC pass  
**Route:** `yahoo → mx1.improvmx.com → gmail`
