# onwua.com — Portfolio Site

Static Hugo site deployed to S3 + CloudFront. No EC2. No server. ~$0/mo.

## Architecture

```
GitHub push to main
      │
      ▼
GitHub Actions (OIDC → existing github-oidc-role)
      │
      ├── hugo --minify  (builds site/public/)
      │
      ├── aws s3 sync → onwua-portfolio-site
      │
      └── cloudfront create-invalidation
                │
                ▼
          CloudFront CDN
                │
          onwua.com (Route53 alias)
```

## First-time deploy (do this once)

### 1. Point onwua.com nameservers to Route53

After `terraform apply`, get your Route53 hosted zone NS records:

```bash
aws route53 list-hosted-zones-by-name --dns-name onwua.com \
  | jq '.HostedZones[0].Id' -r
```

Then:
```bash
aws route53 get-hosted-zone --id <zone-id> \
  | jq '.DelegationSet.NameServers'
```

Copy those 4 NS records into Namecheap → Advanced DNS for onwua.com → 
change nameservers to "Custom DNS" and paste the Route53 NS values.

### 2. Terraform apply

```bash
cd infra/portfolio

# If you don't have a Route53 hosted zone for onwua.com yet:
aws route53 create-hosted-zone \
  --name onwua.com \
  --caller-reference $(date +%s)

terraform init
terraform apply
```

ACM certificate validation is automatic — Terraform creates the DNS records
and waits for validation. Takes 2–5 minutes.

### 3. Add GitHub repo variables

After `terraform apply` outputs print:

```
# In your GitHub repo → Settings → Secrets and variables → Actions → Variables:
S3_BUCKET               = onwua-portfolio-site
CLOUDFRONT_DISTRIBUTION = <from terraform output cloudfront_distribution_id>

# Already exists as a secret in platform-foundation:
AWS_ACCOUNT_ID          = <your account ID>
```

### 4. Attach deploy policy to github-oidc-role

```bash
# Get the policy ARN from terraform output or console
aws iam attach-role-policy \
  --role-name github-oidc-role \
  --policy-arn arn:aws:iam::<account-id>:policy/onwua-portfolio-deploy-policy
```

### 5. Push to main — site deploys automatically

```bash
git add .
git commit -m "feat(portfolio): initial onwua.com deploy"
git push origin main
```

## Local development

```bash
cd site
hugo server --buildDrafts
# → http://localhost:1313
```

## Cost breakdown

| Resource | Cost |
|---|---|
| S3 storage (< 50MB static site) | $0.00 |
| S3 requests (personal traffic) | < $0.01 |
| CloudFront (free tier: 1TB/mo, 10M requests) | $0.00 |
| Route53 hosted zone | $0.50/mo |
| ACM certificate | $0.00 |
| **Total** | **~$0.50/mo** |

The only real cost is the Route53 hosted zone at $0.50/month.
If you already have onwua.com in Route53 from a previous setup, it's already paid.

## File structure

```
onwua-portfolio/
├── .github/
│   └── workflows/
│       └── deploy-portfolio.yml   CI/CD pipeline
├── infra/
│   └── portfolio/
│       ├── main.tf                S3 + CloudFront + ACM + Route53 + IAM
│       └── outputs.tf
└── site/
    ├── hugo.toml                  Hugo config
    ├── content/
    │   └── resume.md
    └── layouts/
        ├── index.html             Homepage
        └── _default/
            ├── baseof.html        Base template
            └── single.html        Content pages
```
