+++
title = "Hugo CLI Cheatsheet"
description = "Reference guide for the Platform Foundation Hugo helper scripts used to scaffold, build, and publish the knowledge base."
summary = "Learn how to create new knowledge domains, bottle reviews, articles, and publish changes using the Hugo CLI helper scripts."
date = 2026-07-08
draft = false

type = "kb-article"

tags = [
  "hugo",
  "cli",
  "knowledge-base",
  "automation",
  "tooling"
]

categories = [
  "Hugo"
]

weight = 20
+++

# Overview

The Platform Foundation Hugo CLI consists of a growing collection of helper scripts that automate common documentation tasks.

Rather than manually creating directories, copying `_index.md` files, selecting archetypes, and remembering build commands, the CLI standardizes those operations into repeatable commands.

<!--more-->

# Why It Matters

Documentation should be as easy to create as code.

By automating repetitive tasks, contributors can focus on writing high-quality content instead of remembering directory structures or Hugo commands.

The CLI also enforces a consistent layout across every knowledge domain.

---

# Where It Fits

```
Need Documentation
        │
        ▼
Hugo Helper Script
        │
        ▼
Scaffold Content
        │
        ▼
Write Article
        │
        ▼
Build Hugo Site
        │
        ▼
Deploy Platform
```

---

# The Big Picture

The helper scripts are located in:

```text
tools/hugo/
```

Current toolkit:

```
create-kb-domain.sh
create-kb-bottle.sh
create-kb-article.sh

(build.sh)
(refresh.sh)
(publish.sh)
```

As the platform evolves, additional automation scripts will be added to this directory.

---

# Core Commands

## Create a Knowledge Base Domain

```bash
tools/hugo/create-kb-domain.sh beer
```

Creates:

```
content/kb/beer/
```

including all standard subsections.

---

## Create a Bottle Review

```bash
tools/hugo/create-kb-bottle.sh \
beer \
goose-island-bourbon-county-brand-stout
```

Creates:

```
content/kb/beer/bottles/goose-island-bourbon-county-brand-stout.md
```

using the appropriate archetype.

---

## Create a Knowledge Article

```bash
tools/hugo/create-kb-article.sh \
infrastructure \
hugo \
hugo-cli-cheatsheet
```

Creates:

```
content/kb/infrastructure/hugo/hugo-cli-cheatsheet.md
```

using the shared KB article archetype.

---

# Build Workflow

Future helper scripts will automate the build process.

## Build

```bash
tools/hugo/build.sh
```

Equivalent to:

```bash
docker build -t hugo .
```

---

## Refresh

```bash
tools/hugo/refresh.sh
```

Equivalent to:

```bash
platform refresh hugo
```

---

## Publish

```bash
tools/hugo/publish.sh
```

Will eventually automate:

- Docker build
- Docker tag
- ECR push
- Platform refresh
- Deployment validation

---

# Engineering Analogy

The helper scripts serve the same purpose as Terraform modules.

Rather than repeatedly performing low-level operations, they encapsulate best practices behind a consistent interface.

Just as Terraform modules reduce infrastructure duplication, the Hugo CLI reduces documentation boilerplate.

---

# Best Practices

- Create new content using helper scripts instead of manually creating files.
- Keep archetypes generic and reusable.
- Store automation scripts in `tools/hugo`.
- Update helper scripts when the documentation workflow changes.
- Prefer automation over repetitive manual tasks.

---

# Common Mistakes

- Manually creating directories that the helper scripts already generate.
- Editing generated front matter before the archetype.
- Forgetting to publish (`draft = false`).
- Skipping the helper scripts and creating inconsistent content structures.

---

# Pro Tip

> If you perform the same documentation task more than two or three times, consider adding a new helper script to the Hugo CLI rather than repeating the manual workflow.

---

# Key Takeaways

- The Hugo CLI standardizes documentation creation.
- Helper scripts eliminate repetitive scaffolding.
- Archetypes ensure consistent page structure.
- Automation improves speed, consistency, and maintainability.
- The CLI is expected to grow alongside Platform Foundation.

---

# Related Articles

- Hugo Front Matter
- Hugo Archetypes
- Hugo Content Model
- Hugo Template Language

---

# References

- https://gohugo.io/content-management/
- https://gohugo.io/content-management/archetypes/
- https://gohugo.io/content-management/front-matter/

