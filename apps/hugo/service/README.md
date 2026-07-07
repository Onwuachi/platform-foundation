## Hugo Knowledge Base

Documentation about Hugo itself lives under:

content/kb/infrastructure/hugo/

Current topics include:

- Front Matter
- Archetypes
- Content Model
- Template Language
- Taxonomies
- Partials
- Shortcodes
- Data Files

These articles document the architecture of this Hugo platform and serve as internal engineering documentation.

# Onwuachi Hugo Platform

Self-hosted documentation and knowledge platform for the Onwuachi Control Plane.
Built with Hugo, containerized via Docker, deployed through ECR and GitHub Actions.

---

## Architecture Overview

```
apps/hugo/service/
├── archetypes/          Content scaffolding templates
├── content/             All published and draft content
├── data/                YAML data files (services, signals, links)
├── layouts/             Hugo templates and partials
├── static/              Images and static assets
└── hugo.toml            Site configuration
```

Hugo renders static HTML from markdown content and YAML data.
Nginx serves the output inside Docker.
HAProxy handles TLS termination and routing at the edge.

---

## Content Organization

```
content/
├── kb/
│   ├── bourbon/         Bourbon tasting notes, reviews, education
│   └── infrastructure/  DevOps and platform engineering KB
│       ├── aws/
│       ├── docker/
│       ├── general/
│       ├── hugo/
│       ├── systemd/
│       └── terraform/
├── culture/             Media, interests, links
├── engineering/         Engineering posts
├── platform/            Platform documentation
├── recipes/             Pitmaster runbooks
└── signals/             Telemetry and observability status
```

**Protected paths** (HAProxy basic auth required):
- `/kb/` — Knowledge base
- `/private/` — Personal notes
- `/family/` — Family content

---

## Archetypes

Never use `touch` to create content files. Always use Hugo archetypes.

### KB Article (infrastructure, general)
```bash
hugo new --kind kb-article kb/infrastructure/<section>/<article>.md
```

### Bourbon Bottle Review
```bash
hugo new --kind bourbon-bottle kb/bourbon/bottles/<bottle>.md
```

Both archetypes generate proper frontmatter, section structure, and `draft: true`
so pages don't publish until explicitly ready.

---

## Build Commands

### Local build check
```bash
hugo --minify --gc
```

### Full deploy cycle
```bash
docker build -t hugo .
docker tag hugo 046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    046685909731.dkr.ecr.us-east-1.amazonaws.com
docker push 046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest
platform refresh hugo
```

### Shortcut (builds + pushes + deploys in one)
```bash
platform deploy hugo
```

`platform deploy` handles ECR login automatically. Use it instead of the
manual sequence to avoid token expiry errors.

---

## Development Workflow

### Publishing a draft article
```bash
# 1. Flip draft to false
sed -i 's/^draft = true/draft = false/' content/kb/<path>/<article>.md
# or for YAML frontmatter:
sed -i 's/^draft: false/draft: true/' content/kb/<path>/<article>.md

# 2. Build and verify locally
hugo --minify --gc

# 3. Deploy
platform deploy hugo

# 4. Commit
git add content/kb/<path>/<article>.md
git commit -m "feat(kb): publish <article>"
git push origin main
```

### Adding a new recipe
```bash
# 1. Create content file with proper YAML frontmatter
vi content/recipes/<recipe-name>.md

# 2. Add thumbnail image
cp /path/to/image.png static/images/<recipe-name>.png

# 3. Register image in recipes list template
vi layouts/recipes/list.html
# Add entry to $imgMap dict

# 4. Build and deploy
hugo --minify --gc && platform deploy hugo
```

### Adding a new bourbon bottle
```bash
hugo new --kind bourbon-bottle kb/bourbon/bottles/<bottle-name>.md
vi content/kb/bourbon/bottles/<bottle-name>.md
# Fill in frontmatter and tasting notes
# Set draft = false when ready
hugo --minify --gc && platform deploy hugo
```

---

## Frontmatter Rules

Hugo requires valid YAML or TOML in the frontmatter block.

**YAML lists use `-` not `*`:**
```yaml
# Correct
tags:
  - bourbon
  - review

# Wrong — will break the build
tags:
* bourbon
* review
```

**TOML frontmatter** (used by archetypes) uses `+++` delimiters:
```toml
+++
title = 'Article Title'
draft = true
+++
```

**YAML frontmatter** (used by hand-written content) uses `---` delimiters:
```yaml
---
title: "Article Title"
draft: false
---
```

Do not mix `+++` and `---` in the same file.

---

## HAProxy Auth

The `/kb/`, `/private/`, and `/family/` paths require HTTP Basic Auth.

Password hash is stored in AWS SSM Parameter Store:
```
/platform/haproxy/auth/derrick  (SecureString)
```

To rotate the password:
```bash
HASH=$(openssl passwd -6 -salt $(openssl rand -hex 8) NewPassword)

aws ssm put-parameter \
  --name "/platform/haproxy/auth/derrick" \
  --type "SecureString" \
  --value "$HASH" \
  --overwrite \
  --region us-east-1

platform rehydrate
```

**Important:** Ubuntu 22.04 system `crypt()` does NOT support `apr1` hashes
(`$apr1$...`). Always use SHA512 (`$6$...`) generated with `openssl passwd -6`.

---

## Data Files

YAML data files drive dynamic content on the homepage and platform page.

| File | Purpose |
|---|---|
| `data/platform/services.yaml` | Service list and status badges |
| `data/signals/telemetry.yaml` | Observability signal states |
| `data/culture/links.yaml` | Culture page links |
| `data/engineering/stack.yaml` | Engineering stack reference |

---
## Content Authoring Workflow

New content should be created using Hugo archetypes rather than copying existing files.

Examples:

```bash
# Infrastructure KB article
hugo new --kind kb-article \
  kb/infrastructure/hugo/my-new-article.md

# Bourbon bottle review
hugo new --kind bourbon-bottle \
  kb/bourbon/bottles/rare-breed.md
```

Archetypes provide:

- Consistent Front Matter
- Standard document structure
- Automatic title generation
- Automatic timestamps
- Reusable templates

Avoid manually copying existing Markdown files.

---

## Front Matter Philosophy

Every content page begins with Front Matter.

Think of Front Matter as metadata for content.

Infrastructure analogy:

Terraform
    variables.tf
        ↓
Terraform Engine
        ↓
Infrastructure

Hugo

Front Matter
      ↓
Hugo
      ↓
Generated HTML

The Markdown body contains the content.

The Front Matter contains the metadata Hugo uses during the build.

Custom Front Matter fields are encouraged where they improve organization and automation.

---


## Hugo KB Learning Path

The `content/kb/infrastructure/hugo/` section teaches Hugo from a
DevOps/platform engineering perspective. Articles follow this dependency order:

```
1. hugo-content-model.md       How Hugo organizes content
2. hugo-front-matter.md        Metadata as code (published)
3. hugo-archetypes.md          Content scaffolding
4. hugo-template-language.md   Go template syntax
5. hugo-partials.md            Reusable template components
6. hugo-taxonomies.md          Automatic content classification
7. hugo-data-files.md          YAML-driven dynamic content
8. hugo-shortcodes.md          Custom content components
```

Core teaching analogy: Hugo follows the same pattern as Terraform and Docker —
structured input → engine → generated output.

---

## Known Constraints

- Recipe thumbnails require manual entry in `layouts/recipes/list.html` `$imgMap`
- ECR tokens expire every 12 hours — re-auth before manual pushes
- `platform deploy hugo` handles ECR login automatically
- `draft: true` pages are excluded from production builds
- Hugo must be run from `apps/hugo/service/` directory, not a parent directory
