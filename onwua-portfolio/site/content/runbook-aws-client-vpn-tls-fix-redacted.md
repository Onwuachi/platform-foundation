# AWS Client VPN — TLS Handshake Fix & Runbook

End-to-end runbook to fix an AWS Client VPN TLS handshake failure, correctly
reissue certificates, rebuild the client profile, and restore private VPC
network access. Based on a real production incident.

## 1. Executive Summary

This runbook covers:

- Fixing AWS Client VPN TLS handshake failures
- Correctly issuing and attaching server certificates (KU/EKU compliant)
- Generating and validating client certificates
- Building a known-good OpenVPN client profile
- Restoring and verifying access to private VPC CIDRs

## 2. Environment Overview

- **Client VPN endpoint:** single active endpoint (region: us-east-2)
- **Client CIDR:** a /22 reserved for VPN clients
- **Associated subnet:** private application subnet
- **Endpoint security group:** permissive, scoped to the VPN use case

**Traffic flow:**

1. User connects using an `.ovpn` profile with a client certificate
2. Client VPN endpoint authenticates the client (mTLS), applies
   authorization rules, applies VPN routes
3. Traffic is NATed through the associated subnet
4. Requests reach VPC resources
5. Return traffic flows back through the VPN endpoint to the client

**Logging:** CloudWatch Log Group dedicated to the Client VPN endpoint.

## 3. Problem Summary (Root Cause)

**Observed client-side errors:**
```
Certificate does not have key usage extension
VERIFY KU ERROR
TLS handshake failed
```

**Root cause:** the server certificate attached to the Client VPN endpoint
lacked proper Key Usage (KU) and Extended Key Usage (EKU) — specifically
`ExtendedKeyUsages = NONE`. OpenVPN enforces EKU when
`remote-cert-tls server` is present in the client config, so the TLS
handshake fails **before routing is even evaluated** — this looked like a
networking/routing problem but was purely a certificate problem.

## 4. High-Level Fix

1. Reissued a proper server certificate with KU: `digitalSignature,
   keyEncipherment`; EKU: `serverAuth`
2. Imported the certificate into ACM
3. Attached it to the Client VPN endpoint
4. Rebuilt a clean `.ovpn` client profile
5. Added both Authorization Rules and Routes (both are required — one
   without the other silently fails)
6. Verified connectivity end-to-end (SSH to a private-subnet host
   succeeded)

## 5. Server Certificate Creation (The Right Way)

**Goal:** TLS-compliant server cert, compatible with AWS Client VPN +
OpenVPN, no handshake failures.

`vpn-server.cnf`:
```ini
[req]
default_bits = 2048
distinguished_name = req_dn
req_extensions = v3_req
prompt = no

[req_dn]
CN = vpn.internal.example

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = vpn.internal.example
DNS.2 = <client-vpn-endpoint-dns>
```

**Generate & sign:**
```bash
openssl genrsa -out vpn-server.key 2048

openssl req -new \
  -key vpn-server.key \
  -out vpn-server.csr \
  -config vpn-server.cnf

openssl x509 -req \
  -in vpn-server.csr \
  -CA vpn-ca.crt \
  -CAkey vpn-ca.key \
  -CAcreateserial \
  -out vpn-server.crt \
  -days 365 \
  -sha256 \
  -extensions v3_req \
  -extfile vpn-server.cnf
```

**Mandatory validation** — must show `Key Usage: Digital Signature, Key
Encipherment` and `Extended Key Usage: TLS Web Server Authentication`:
```bash
openssl x509 -in vpn-server.crt -text -noout
```

## 6. Import Certificate into ACM & Attach

```bash
REGION=us-east-2

CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://vpn-server.crt \
  --private-key fileb://vpn-server.key \
  --certificate-chain fileb://vpn-ca.crt \
  --region $REGION \
  --query 'CertificateArn' \
  --output text)

aws ec2 modify-client-vpn-endpoint \
  --client-vpn-endpoint-id <endpoint-id> \
  --server-certificate-arn $CERT_ARN \
  --region $REGION

aws ec2 describe-client-vpn-endpoints \
  --region $REGION \
  --client-vpn-endpoint-ids <endpoint-id> \
  --query 'ClientVpnEndpoints[0].ServerCertificateArn'
```

## 7. Authoritative Client `.ovpn` Configuration (Golden Reference)

```
client
dev tun
proto udp

remote <client-vpn-endpoint-dns> 443
remote-random-hostname
resolv-retry infinite
nobind

remote-cert-tls server
reneg-sec 0

verb 4
```

**Why this works:**

- `remote-cert-tls server` → enforces server EKU (the actual security control)
- `reneg-sec 0` → required (AWS does not support TLS renegotiation)
- No `verify-x509-name` → prevents future breakage during cert rotation
- Cipher negotiation left to AWS → avoids client incompatibilities

**Explicitly disallowed:**
- `verify-x509-name`
- Removing `remote-cert-tls server`
- Reusing client certs across users
- Uploading client certs to ACM

## 8. Routing & Authorization (Both Required)

```bash
aws ec2 authorize-client-vpn-ingress \
  --region us-east-2 \
  --client-vpn-endpoint-id <endpoint-id> \
  --target-network-cidr 10.0.0.0/8 \
  --authorize-all-groups

aws ec2 create-client-vpn-route \
  --region us-east-2 \
  --client-vpn-endpoint-id <endpoint-id> \
  --destination-cidr-block 10.0.0.0/8 \
  --target-vpc-subnet-id <subnet-id>
```

(Broad `10.0.0.0/8` was used here for a fast recovery; prefer least-privilege
CIDRs long-term.)

## 9. Verification

```bash
ping <private-host-ip>
ssh user@<private-host-ip>
```

Expected: tunnel established, routes present, SSH succeeds.

## 10. Lessons Learned (Critical)

- "Connected" ≠ functional — TLS issues fail before networking is ever
  evaluated
- AWS Client VPN requires **both** an Authorization Rule and a Route
- EKU/KU errors look like "VPN issues" but are certificate problems
- Avoid strict name validation (`verify-x509-name`) unless you own
  certificate rotation forever

## 11. Final Notes

Treat this document as: incident postmortem, operational runbook,
onboarding reference, and certificate rotation guide. Any future changes
should be tested against this baseline.
