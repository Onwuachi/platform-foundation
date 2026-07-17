---
title: "---"
date: 2026-07-14
draft: false
summary: ""
tags: []
categories: ["runbooks"]
---

---
title: "Filescanner: ClamAV Malware Scanning Architecture"
date: 2026-07-14
draft: false
description: ""
summary: ""
tags: []
categories: ["runbooks"]
---

# Filescanner: ClamAV Malware Scanning Architecture

How uploaded files are scanned for malware in a multi-tenant SaaS platform.

## 1. Malware Scanning Solution

**System:** ClamAV in TCP mode, performing signature-based scans to detect
known threats.

**What it scans for:** malware, viruses, and suspicious file types using
regularly updated virus definitions.

**Documentation:** [ClamAV official docs](https://docs.clamav.net)

## 2. Scan Type & Configuration

- Files are scanned using ClamAV TCP mode
- The scanner runs as a dedicated service on a fixed internal port,
  configured to process files dynamically
- Full signature-based scan on each uploaded file to detect known threats
- Flagged files are blocked from further processing and logged for security
  review

## 3. Origins & Security Measures

- Only files originating from authorized application domains are processed
- Temporary files are staged in a dedicated scan directory before analysis
- Strict validation ensures files cannot bypass scanning before entering
  the system

## 4. Edge Routing (HAProxy)

The reverse proxy routes upload/download traffic to the scanner service
based on path and query parameters, then forwards clean traffic on to the
underlying application:

```
frontend ft_app_tcp
  acl is_ftp_download url_param urlp(cmd) file-download
  acl is_ftp_upload   url_param urlp(cmd) file-upload

  use_backend bk_file_scanner       if HTTP { path_beg /uc/ftp }
  use_backend bk_uc_direct_http     if HTTP { path_beg /ftp } is_ftp_download
  use_backend bk_upload_filescanner if HTTP { path_beg /ftp } is_ftp_upload

backend bk_file_scanner
  mode http
  # strip the app path prefix now that we're behind HAProxy
  http-request replace-path /uc/(.*) /\1
  http-request set-query %[query]&cmd=fwd&fwd_loc=http%%3A%%2F%%2Fapp%%3A80
  server FILESCANNERUPLOAD filescanner:80
  # cookies back to the app with the full path
  http-response replace-value Set-Cookie (.*)Path=(.*) \1Path=/uc\2

backend bk_upload_filescanner
  mode http
  timeout server 300s
  http-request set-query %[query]&cmd=fwd&fwd_loc=http%%3A%%2F%%2Fapp%%3A80
  server FILESCANNERUPLOAD filescanner:80
```

## 5. Filescanner Container Config

```xml
<config>
  <servers>
    <server addr='all' port='80'>
      <http/>
      <rxml/>
    </server>
  </servers>
  <resources>
    <wwwLocal>www</wwwLocal>
    <type>clamav_tcp</type>
    <host><!-- internal ClamAV service host --></host>
    <port>3310</port>
    <system>SCAN {file}</system>
  </resources>
  <tmpPath>/scandir/</tmpPath>
  <origins>
    <origin>https://*.example-app.com</origin>
    <origin>linklive://*.example-app.com</origin>
  </origins>
</config>
```

## 6. Container Lifecycle

**Start:**
```bash
#!/bin/sh
service=filescanner
source ../.service

SCANDIR="$(realpath /mnt/efs/share/clamav/scandir)"
[ ! -d ${SCANDIR} ] && sudo mkdir -p ${SCANDIR}

docker run \
  --platform linux/amd64 \
  --name ${service}-${INSTANCE_NAME} -dt --restart unless-stopped \
  --network ${INSTANCE_NAME} --hostname ${hostname} -it --ulimit core=-1 \
  --mount type=bind,source="$(realpath ../../$inst/app/${service})",target=/etc/app \
  --mount type=bind,source="${SCANDIR}",target=/scandir \
  <registry>/${service}:${VERSION} /config_path="/etc/app/"
```

**Stop:**
```bash
#!/bin/sh
service=filescanner
source ../.service
docker container rm -f ${service}-${INSTANCE_NAME}
```

## 7. DB Definitions & Update Tracking

| File | Purpose |
|---|---|
| `main.cvd` | Core virus definitions |
| `daily.cld` | Daily updates to virus signatures |
| `bytecode.cld` | Bytecode signatures for advanced detection |
| `freshclam.dat` | Metadata for update tracking (last update time) |

`freshclam` runs on a schedule, tests each new database before activating
it, and notifies `clamd` on successful update. Watch for version-lag
warnings (`ClamAV installation is OUTDATED`) — these indicate the running
engine version has fallen behind the recommended version even though
signature databases are current; engine and signature versions are tracked
and reported separately.

`clamd` performs a periodic self-check (`SelfCheck: Database status OK`)
independent of `freshclam`'s update cycle — useful for confirming the
running daemon, not just the on-disk database files, is healthy.

## 8. References

- [ClamAV Documentation](https://docs.clamav.net)
- [ClamAV Docker Installation](https://docs.clamav.net/manual/Installing/Docker.html)
