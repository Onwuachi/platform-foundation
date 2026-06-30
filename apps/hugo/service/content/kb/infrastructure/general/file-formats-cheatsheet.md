---
title: "KB-REF-001: File Format Cheat Sheet — Reading Any Config File on Sight"
date: 2026-06-25
description: "A field guide to every file format that shows up in DevOps work — Terraform, YAML, JSON, shell, systemd units, Dockerfiles, JS — what each one is actually FOR, how to tell them apart at a glance, and the one or two syntax rules that matter most in each."
tags: ["reference", "terraform", "yaml", "json", "bash", "systemd", "cheatsheet"]
categories: ["kb"]
summary: "You don't need to memorize every format — you need to recognize what KIND of file you're looking at and know the 2-3 rules that actually matter for each one. This is that map."
---

# KB-REF-001: File Format Cheat Sheet

**Date:** June 25, 2026
**Purpose:** A field guide for recognizing and safely editing every file
format that shows up in this platform — without needing a CS background.

---

## The big idea first

Every file format you touch in this work falls into one of three jobs:

```
1. DESCRIBE DATA           (JSON, YAML)
2. DESCRIBE INFRASTRUCTURE (Terraform .tf, Packer .pkr.hcl)
3. GIVE INSTRUCTIONS       (Bash .sh, JavaScript .js, Python .py)
```

Systemd unit files and Dockerfiles are a hybrid — mostly data, with a tiny
bit of instruction baked in. Once you know which of the three jobs a file
is doing, you already know 80% of how to read it safely.

---

## JSON — .json

Job: Describe data. Nothing else. No comments, no logic, no instructions.

Looks like:
```json
{
  "name": "platform-api",
  "port": 3000,
  "tags": ["api", "production"]
}
```

The only rules that matter:
- Every key and string value needs double quotes, always — "name" not
  name or 'name'
- Commas between items, no trailing comma after the last item (this is
  the #1 JSON syntax error)
- { } = an object (a labeled box of fields). [ ] = a list of items
- No comments allowed. Ever.

Where you've seen it: manifest.json (Packer's build output),
hugo_stats.json (Hugo's asset stats) — both auto-generated, you rarely
hand-write JSON in this stack.

---

## YAML — .yml / .yaml

Job: Describe data, same as JSON, but designed to be easier for humans
to type and read. This is the format you've fought with the most
(prometheus.yml, GitHub Actions workflows, Hugo frontmatter).

Looks like:
```yaml
name: platform-api
port: 3000
tags:
  - api
  - production
```

The rules that actually matter (and the ones that bite you):
- Indentation is the entire structure. There are no { } or [ ] to
  visually show nesting — a line is "inside" another line purely because
  it's indented further. This is exactly what broke prometheus.yml
  earlier — an ec2_sd_configs: line got deleted, leaving its child lines
  indented as if they belonged to something, but with no parent key
  above them. YAML doesn't error loudly on this the way you'd hope.
- Use spaces, never tabs, for indentation.
- key: value — note the space after the colon.
- A dash "- " starts a list item. Same indentation level = same list.
- # starts a comment (unlike JSON, comments ARE allowed)
- Three dashes --- can separate multiple "documents," or (in Hugo) mark
  the start/end of frontmatter

Quick gut-check before trusting any YAML edit: does every child line
line up with consistent indentation under its parent? If unsure, paste
it into an online YAML validator before committing.

Where you've seen it: prometheus.yml, .github/workflows/*.yml,
Hugo frontmatter, docker-compose.yml, Kubernetes manifests (future EKS work).

---

## Terraform — .tf

Job: Describe infrastructure — "I want this AWS resource to exist with
these settings." Not a list of steps to run; a description of a desired
end state. Terraform figures out how to get there.

Looks like:
```hcl
resource "aws_iam_policy" "packer_policy" {
  name        = "packer-build-policy"
  description = "Permissions for GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [...]
  })
}
```

The rules that matter:
- resource "TYPE" "local_name" { } is the core pattern — TYPE is an exact
  AWS resource type name, local_name is a label YOU pick to refer to it
  elsewhere in your own code
- key = value — note the equals sign, not a colon like YAML. This is the
  fastest way to tell Terraform apart from YAML at a glance.
- You'll often see jsonencode({ ... }) inside a .tf file — Terraform
  embedding a literal JSON-shaped IAM policy document as a string value.
  This is exactly why iam_github.tf has that nested JSON-looking block.
- Comments use # or //
- data "TYPE" "name" { } (no resource) means "look up something that
  already exists" rather than "create something new"

The workflow that matters more than syntax:
```
terraform plan    # shows what WOULD change — never skip this
terraform apply   # actually makes the change
```
plan is non-destructive and safe to run as often as you want.

Where you've seen it: every file in infra/, onwua-portfolio/infra/portfolio/main.tf.

---

## HCL (Packer) — .pkr.hcl

Job: Same HCL syntax as Terraform (key = value, resource/block { }
patterns), but describes a build process for a machine image, not
ongoing infrastructure.

The one Packer-specific gotcha you hit tonight: paths inside
provisioner "shell" { scripts = [...] } are relative to wherever the
packer build command is run from, not relative to the .pkr.hcl file's
own location. This is why the GitHub Actions workflow needed
working-directory: infra/packer/ops — to make the command run from the
same folder you've always manually cd'd into.

---

## Shell scripts — .sh

Job: Give instructions — a literal sequence of commands to run, top to
bottom, exactly like typing them into a terminal yourself.

Looks like:
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Installing..."
apt-get update
apt-get install -y curl
```

The rules that matter:
- #!/usr/bin/env bash (the "shebang") on line 1 tells the system which
  program should run this file
- set -euo pipefail near the top means "stop immediately on any error"
  instead of silently continuing after something fails
- $VARIABLE or ${VARIABLE} reads a variable's value
- This is the format where the heredoc bug from earlier happened —
  <<EOF (unquoted) substitutes $VARIABLES immediately when the script
  is being written/sent, vs. \$VARIABLE (escaped) which stays literal
  text until whatever runs the script later resolves it. See
  KB-CLI-001 (sed cheatsheet) for more on this exact trap.
- || means "or, if that failed" — command || true means "run this, and
  if it fails, don't treat that as a script-ending error"

Where you've seen it: every file in infra/packer/ops/scripts/, tools/platform.

---

## systemd unit files — .service / .timer

Job: A hybrid — mostly data (describing a background service's
properties) with the actual "what to run" given as a literal shell
command string.

Looks like:
```ini
[Unit]
Description=Grafana
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker run --name grafana ...
Restart=always

[Install]
WantedBy=ops.target
```

The rules that matter:
- [Section] headers in square brackets group related settings — this
  format is called "INI-style," distinct from both YAML and JSON
- Key=Value — no spaces around the = is conventional
- ExecStart= is the actual command systemd runs to start the service —
  this is where docker run --network host ... lives, which is why
  fixing Grafana's networking meant editing THIS file specifically
- [Unit] describes dependencies/metadata, [Service] describes runtime
  behavior, [Install] describes when it should auto-start

Where you've seen it: every file in infra/packer/ops/systemd/.

---

## Dockerfile — no extension, literally named Dockerfile

Job: Instructions for building a container image, one layer at a time.

Looks like:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
CMD ["node", "server.js"]
```

The rules that matter:
- Each line is a separate "instruction" — FROM, RUN, COPY, CMD, EXPOSE,
  ENV are the common ones
- Order matters and affects build speed (Docker caches each layer — put
  things that change rarely before things that change often)
- CMD (what runs when the container starts) is different from RUN
  (what runs once, during the image build)

---

## JavaScript — .js

Job: Give instructions, but in JavaScript syntax — used here for the
CloudFront Function (index-rewrite.js).

Looks like:
```javascript
function handler(event) {
    var request = event.request;
    if (request.uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    return request;
}
```

The rules that matter (just enough to read it):
- function name(params) { } defines a reusable block of instructions
- var / let declares a variable
- .endsWith(), .includes() are built-in string methods
- if (condition) { } runs the block only if the condition is true
- Semicolons ; end most lines

---

## Markdown — .md

Job: Formatted text for humans to read — what this KB file is written
in. Not data, not instructions — prose with light formatting hints.

The rules that matter:
- #, ##, ### = heading levels
- **bold**, *italic*
- backtick-code-backtick for inline code, triple backticks for blocks
- A YAML block between --- markers at the very top is "frontmatter" —
  structured metadata (title, date, tags) Hugo reads separately from
  the Markdown content below it. This is exactly the YAML-inside-
  Markdown pattern that caused the KB rendering bug earlier — when
  frontmatter was missing, Hugo had no title: to read.

---

## The fastest way to identify any unfamiliar file

Look at these three things, in order:

1. The file extension (.tf, .yml, .json, .sh) — usually tells you the
   format immediately
2. The first non-blank line — a shebang line means shell script.
   resource "..." means Terraform. A curly brace means JSON or possibly
   YAML. A bracketed section name means systemd. Three dashes means YAML
   doc start or Markdown frontmatter.
3. Does it use a colon or an equals sign for key-value pairs? Colon
   leans YAML or systemd-adjacent. Equals sign leans Terraform, shell
   variables, or ini-style config.

You will get fast at this with repetition — you already are. Six months
ago an orphaned config block silently breaking a YAML file would have
been a mystery; tonight you correctly diagnosed it as a missing parent
key within minutes of seeing the malformed structure.

---

## One honest note

You don't need to become fluent in writing JavaScript, or memorize every
Terraform resource type, or have every YAML indentation rule memorized.
What actually matters — and what you're already doing — is:

1. Recognizing which kind of file you're looking at
2. Knowing the 2-3 rules that most commonly break that format
3. Having a place (this KB, or asking) to check when something doesn't
   parse as expected

That's the real skill. The formats themselves are just vocabulary — and
vocabulary you look up as needed is just as valid as vocabulary you've
memorized. Professional engineers reference docs and cheat sheets
constantly; the difference between you and "a developer" is mostly
title, not capability.
