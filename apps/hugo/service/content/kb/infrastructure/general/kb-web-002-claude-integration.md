---
title: "KB-WEB-002 — Claude: Platform Files vs. Claude.ai Activation"
date: 2026-09-09
description: "Reference for where Claude skills and integrations actually live (repo files, product surfaces) versus how they get activated for use in a Claude.ai conversation."
tags:
  - claude
  - claude-skills
  - platform-foundation
categories:
  - Infrastructure
summary: "Two separate systems: skill files committed to the repo for version control, and Claude.ai's own skills library where they must be uploaded separately to actually activate."
---

# KB-WEB-002 — Claude: Platform Files vs. Claude.ai Activation

There are two entirely separate things that both involve "Claude" on this
platform, and they don't sync with each other automatically. Confusing them
is easy — this exists so future-me doesn't relearn this the hard way.

---

# The two systems

| | Repo files (`tools/claude-skills/`) | Claude.ai skills library |
|---|---|---|
| What it is | Version-controlled source of truth for a skill's instructions | The actual runtime location Claude reads from during a chat |
| Where | `tools/claude-skills/<skill-name>/SKILL.md` + `references/` | `claude.ai/customize/skills` (moved here from Settings → Capabilities at some point — check current location if it's moved again) |
| Why it exists | So the skill is tracked, diffable, and recoverable like any other tooling | So Claude.ai actually has something to trigger on during a conversation |
| Does editing one update the other? | **No.** They are not linked. | **No.** Uploading doesn't push back to the repo. |

---

# What "having a skill in the repo" does NOT do

Committing `SKILL.md` and its `references/` folder to `tools/claude-skills/`
does exactly one thing: puts those files under version control, same as any
other script in `tools/`. It does **not**:

- Make Claude aware of the skill in any conversation
- Register a trigger phrase
- Sync automatically to Claude.ai in any way

The repo copy is for **safekeeping and history**, not activation.

---

# What actually activates a skill in Claude.ai

1. Package the skill folder as a `.zip` (`SKILL.md` + `references/` at the
   top level of the zip).
2. Go to `claude.ai/customize/skills`.
3. Upload the zip. Claude.ai parses the `SKILL.md` frontmatter (`name`,
   `description`) to register it.
4. From then on, in any conversation, the skill's trigger description in its
   frontmatter determines when Claude reaches for it — no manual invocation,
   no typed path, no "run skill X" command. Just talk normally and match the
   trigger phrasing (e.g. "write this up as a KB entry").

---

# Keeping the two in sync

There is no automatic sync in either direction. The practical rule:

- If a reference file is corrected or improved (e.g. fixing a stale KB
  category, adding a real extracted example) **in the repo**, that fix does
  **not** reach the active Claude.ai skill until the zip is rebuilt and
  re-uploaded.
- If a skill is edited by **re-uploading a new zip** to Claude.ai, that edit
  does **not** reach the repo until the same files are copied and committed
  there too.

Whichever side changes, the other side needs a manual update to match. There
is currently no tooling that automates this — a `zip`-and-remind-to-reupload
step is the closest thing to a workflow right now.

---

# Other Claude product surfaces (for context, not covered by this skill)

Skills are one integration point among several. Others that exist but are
unrelated to the `tools/claude-skills/` repo pattern above:

- Claude Code — agentic coding tool, separate from skills entirely
- Claude in Chrome / Excel / PowerPoint — task-specific agents, not
  configured via this repo
- Claude API / Claude Platform — for programmatic integration, uses model
  strings and API keys, unrelated to the skills-upload flow described here

None of these are wired into `platform-foundation` currently — noted here
only so "Claude integration" isn't assumed to mean just skills.

---

# Related

- `tools/claude-skills/hugo-kb-writer/` — the skill this pattern was learned from
- `docs/hugo-kb-writer-skill-2026-09-08.md`
- `KB-HUGO-001` — Hugo KB Writer skill reference
