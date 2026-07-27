+++
title = "Hugo Front Matter: Metadata as Code"
description = "Understanding Hugo front matter through the lens of infrastructure engineering."
summary = "Learn how front matter works, why it matters, and how it compares to Terraform variables and infrastructure metadata."

date = 2026-07-06
draft = false

type = "kb-article"

weight = 20

tags = [
  "hugo",
  "front-matter",
  "templates",
  "metadata",
  "knowledge-base"
]

categories = [
  "Hugo"
]
+++

# Overview

Every content page in Hugo begins with **Front Matter**.

Front Matter is structured metadata that tells Hugo how a page should be rendered, organized, and displayed. Although it may look like a small block of configuration at the top of a Markdown file, it is one of the most important concepts in Hugo because every page passes through it during the build process.

For infrastructure engineers, Front Matter is best understood as **metadata for content**, much like variables and configuration files are metadata for infrastructure.

<!--more-->

# Why It Matters

Without Front Matter, Hugo only sees a Markdown document.

With Front Matter, Hugo understands:

- The page title
- Publication date
- Draft status
- Categories
- Tags
- Custom metadata
- Which template to use
- How the page fits into the rest of the site

Nearly every Hugo feature depends on information defined in Front Matter.

---

# The Big Picture

![Hugo Front Matter vs Terraform Workflow](/images/hugo-front-matter-vs-terraform-workflow.png)

Just as Terraform separates configuration from execution, Hugo separates content from presentation.

The Markdown file contains the article, while the Front Matter provides the structured data Hugo needs to generate the final website.

---

# What is Front Matter?

Front Matter is the metadata block located at the beginning of every content file.

For example:

```toml
+++
title = "My First Hugo Page"
date = 2026-07-06
draft = false

tags = ["hugo","documentation"]

categories = ["Infrastructure"]
+++
```

Everything above the closing `+++` is Front Matter.

Everything below it is the Markdown content that becomes the page.

---

# Supported Formats

Hugo supports three Front Matter formats.

## TOML

```toml
+++
title = "Example"
draft = false
+++
```

Uses `+++`

---

## YAML

```yaml
---
title: Example
draft: false
---
```

Uses `---`

---

## JSON

```json
{
  "title": "Example",
  "draft": false
}
```

Used less frequently but fully supported.

---

# Anatomy of Front Matter

A typical page contains fields such as:

| Field | Purpose |
|--------|---------|
| title | Display title |
| date | Publication date |
| draft | Publish or hide page |
| description | Short page description |
| summary | Search and preview text |
| tags | Cross-reference related content |
| categories | Organize articles |
| weight | Manual ordering |
| type | Select layouts |
| aliases | Redirect old URLs |

Hugo also allows custom fields.

For example:

```toml
proof = 100
distillery = "Jim Beam"
rating = 8.5
```

Those fields can later be displayed inside templates.

---

# Engineering Analogy

Front Matter becomes much easier to understand when compared to Terraform.

| Hugo | Terraform |
|------|-----------|
| Front Matter | variables.tf |
| Markdown | Resource definitions |
| Templates | Terraform engine |
| Generated HTML | Infrastructure resources |
| Build | terraform apply |

Both systems follow the same pattern:

```
Configuration

↓

Processing Engine

↓

Generated Output
```

Instead of building EC2 instances, Hugo builds web pages.

---

# Real-World Example

The bourbon bottle reviews in this knowledge base use a custom Front Matter schema.

```toml
brand = "Knob Creek"

expression = "Smoked Maple"

proof = 90

rating = 8

would_buy_again = true
```

Those values aren't part of Hugo itself.

They are custom metadata created specifically for this project.

The same approach could be used for recipes, AWS services, architecture documents, or runbooks.

---

# Best Practices

- Keep Front Matter concise.
- Use consistent naming conventions.
- Prefer reusable custom fields.
- Use archetypes to generate Front Matter automatically.
- Avoid manually recreating metadata for each page.
- Think of Front Matter as structured data, not documentation.

---

# Common Mistakes

- Mixing Markdown with Front Matter.
- Incorrect YAML indentation.
- Forgetting to close the metadata block.
- Using inconsistent field names.
- Forgetting to set `draft = false` when publishing.

---

# Key Takeaways

- Every Hugo page begins with Front Matter.
- Front Matter is metadata, not page content.
- Hugo uses this metadata to organize and render pages.
- Custom metadata enables powerful templates and reusable layouts.
- Archetypes automate Front Matter generation.

---

# Related Articles

- Hugo Content Model
- Hugo Archetypes
- Hugo Template Language
- Hugo Partials

---

# Official Documentation

- https://gohugo.io/content-management/front-matter/
- https://gohugo.io/content-management/archetypes/
- https://gohugo.io/content-management/

---

# References

- Hugo Documentation — Front Matter
- Hugo Documentation — Content Management
