# Recipe / Smoke Session Log Template

Source: extracted from `content/recipes/smoke-sessions/2026-07-03-independence-day.md`.

Scaffolding script: `tools/hugo/create-kb-recipe.sh` (not `create-kb-article.sh` — recipes
have their own dedicated script, confirmed present in `tools/hugo/`).

Format: **YAML** (`---` delimiters) — different from bottle reviews (TOML).

## Frontmatter

```yaml
---
title: "2026 Independence Day Smoke Session"
date: 2026-07-03
draft: false

image: "/images/recipes/slug-name.png"

description: "One-sentence factual description of what this log covers."

summary: "One-sentence summary of the record's purpose (e.g. 'Operational record documenting cook timeline, observations, experiments, and lessons learned.')."

tags:
  - brisket
  - technique-tag
  - bbq
---
```

No `categories` field observed in this example (unlike tech KB and bottle reviews) — omit unless Derrick's repo convention for this subfolder shows otherwise; ask if unsure.

## Body structure — operational/log style, NOT review style

This is a production log, not a tasting review. No rating block, no "Buy Again" verdict. Structure:

```markdown
# <Title>

> One-line framing blockquote describing the session.

---

# Objectives

Primary goals:

- [bulleted list of what this cook/session is trying to accomplish]

---

# Equipment

- [bulleted list]

---

# Fuel Strategy   (smoke sessions specifically — omit for non-smoking recipes)

## Primary Smoke Phase / Finish Phase
[what fuel, why, decision made]

---

# Meat Preparation   (or "Ingredients"/"Prep" for non-BBQ recipes)

## <Protein/Component>
- [prep steps as bullets]

---

# Timeline

## <Time period label, e.g. "Early Morning">
[narrative + specific temps/times as they occurred]

## <Wrap/Transition events as their own subsections>

---

# Operational Incident   (only if something unexpected happened — omit if none)

## <Incident name>
[what happened, recovery actions taken, lesson learned inline]

---

# <Component> Results

[Observations per experiment/component, e.g. "Rack A" / "Rack B" comparisons]

---

# Major Lessons Learned

## 1. <Lesson title>
[explanation]

## 2. <Lesson title>
[explanation]

(numbered, one per distinct takeaway)

---

# Runbook Updates Generated

This cook resulted in updates to:

- [list of runbook/technique docs that should be updated as a result of this session]

---

# Overall Assessment

Overall Success: **Excellent / Good / Mixed / Poor**

Objectives achieved:

- [bulleted list matching back to Objectives section]

---

*"[optional closing italicized reflective line]"*
```

## Notes

- Voice is operational/technical, not narrative-reflective like bottle reviews — reads like a lab notebook or runbook, with specific temps, times, and decisions logged.
- "Lesson Learned" call-outs appear inline within incident sections AND get rolled up into the "Major Lessons Learned" section at the end — don't skip the rollup even if lessons were already mentioned inline.
- "Runbook Updates Generated" section is important — it's how this log feeds back into Derrick's technique/runbook docs elsewhere in the KB. Always ask what runbooks this session should update, don't invent them.
- If this is a standalone recipe (not a full smoke-session log), the structure compresses — likely just Ingredients/Prep, Timeline or Steps, and Notes/Lessons. Ask Derrick if he wants the full session-log structure or a simpler recipe-only structure before drafting, if it's ambiguous which he wants.
