---
name: hugo-kb-writer
description: Draft Hugo content-KB articles, spirit/beer bottle reviews, recipes/smoke-session logs, and family outing posts for Derrick's Platform Foundation site (onwuachi.com), matched to his existing frontmatter conventions and repo layout. Use this ONLY when Derrick explicitly says something like "write this up," "create a KB entry," "write a review for X," "log this smoke session," or "write up the family outing." Do not trigger just because bourbon, beer, recipes, family activities, or infra topics come up in conversation. Produces a complete draft article, the create-*.sh command to scaffold it, and a git commit message that respects Derrick's infra/Hugo pre-commit hook split — and always waits for Derrick's confirmation before he runs anything, since Claude has no direct access to his repo or shell.
---

# Hugo KB Writer

Drafts content for Derrick's Hugo-based personal site (`github.com/Onwuachi/platform-foundation`, deployed to onwuachi.com) across five content types: technical KB articles, spirit/beer bottle reviews, recipes, smoke-session logs, and family outing posts. Matches his established frontmatter and body structure exactly — these aren't generic templates, they're extracted from his actual repo and archetypes (`apps/hugo/service/archetypes/`).

**Important constraint**: This skill has no filesystem or shell access to Derrick's machine or repo. It never claims to "run" a script or "make" a commit — it drafts everything and hands it to Derrick to paste and run himself, per his paste-and-confirm workflow. Say "here's the draft, the script to run, and the commit message" — not "I've created/run/committed."

**Games are out of scope.** Games are static apps (HTML/JS/CSS trees), not KB-style markdown entries — they belong to the separate arcade-builder skill, not this one. A tech-KB *write-up* about building a game (a session log/lessons-learned piece) is in scope as a normal tech KB article; scaffolding a new game is not.

## Trigger discipline

Only activate on explicit requests: "write this up," "create a KB entry," "write a review for X," "log this smoke session," "draft the KB article for Y." A passing mention of bourbon, a KB topic, or a recipe in conversation is NOT a trigger — respond normally.

## Step 1: Identify content type and gather raw material

Ask (or infer from context) which of these applies, if not obvious:

1. **Technical KB article** — infra/tooling reference (`content/kb/<category>/...`)
2. **Spirit/beer bottle review** — bourbon, rum, scotch, or beer (`content/private/<category>/bottles/...`)
3. **Recipe / smoke session log** — cook logs and runbooks (`content/recipes/...`)
4. **Family outing post** — (`content/family/outings/...`) — see privacy note below, this one needs extra care

Get the raw material: Derrick will either paste notes/tasting notes directly, or point at a file/transcript to read (use `view` or `bash_tool` if he references an uploaded file or one already in this container's workspace — Claude cannot read his live repo directly, so ask him to paste the relevant file content if it's not already available).

**Don't invent facts.** If a field isn't in the raw notes (e.g. proof, MSRP, ABV), leave it blank or `"TBD"` matching his own scaffold convention (see `references/bottle-review.md`) rather than guessing.

### Privacy safeguard — family outings only

Derrick keeps real, identifiable photos of his kids **outside** the repo (`~/private-family-photos/`), and only ever references privacy-safe/anonymized public images in Hugo front matter (`static/images/family/...` → `/images/family/...`). When drafting a family outing post:

- Never suggest or assume a specific image filename unless Derrick has stated it — ask which anonymized public image to reference.
- If Derrick pastes something that looks like a real/identifying filename or path (e.g. containing "real," a private-photos path, or anything not already under `static/images/family/`), flag it and ask before including it in any draft or command — don't silently include it.
- Never suggest committing anything from `~/private-family-photos/` or any path outside the repo's `static/` tree.
- Kids are referenced by age only (`kids: ["5", "7"]`), not by name, matching the existing convention — don't add names unless Derrick explicitly provides them for the post itself.

## Step 2: Draft using the matching template

Read the relevant reference file for exact frontmatter fields and body section order:

- `references/tech-kb.md` — technical KB articles (YAML, `KB-XXX-###` IDs)
- `references/bottle-review.md` — bourbon/rum/scotch/beer bottle reviews (TOML, `*-bottle` types)
- `references/recipe-smoke-session.md` — recipes and smoke session logs (YAML, freeform operational structure)
- `references/family-outing.md` — family outing posts (YAML, privacy-safeguarded)

Follow the section order and tone in the reference exactly — don't reorder sections or invent new ones. Derrick's reviews have a specific voice (first-person, narrative, comparison-heavy); match it rather than writing generic tasting-note copy.

### Tech KB IDs

For technical KB articles, suggest the next `KB-XXX-###` number by category (`OBS`, `WEB`, `CLI`, `NET`, `REF`, etc. — extend the pattern for new categories). Ask Derrick to confirm the existing highest number in that category if you don't have it from memory/context — do not guess a number that might collide.

## Step 3: Output three things together

1. **The full draft article** (frontmatter + body), as a fenced code block ready to paste into a file.
2. **The scaffold command** — the matching `tools/hugo/create-*.sh` invocation Derrick should run first to generate the file skeleton at the right path:
   - `create-kb-domain.sh` — new KB category/domain
   - `create-kb-article.sh` — tech KB article
   - `create-kb-bottle.sh` — bourbon/rum/scotch/beer bottle review
   - `create-kb-recipe.sh` — recipe / smoke session log
   - `create-family-outing.sh` — family outing post

   **Do not invent flags or argument syntax for these scripts.** Unless Derrick has pasted the script's actual usage/help output or a prior real invocation in this conversation, don't guess at flag names (`--type`, `--title`, etc.) — that's fabricating a fact about his tooling, the same as guessing a proof or ABV. Instead, name the correct script and ask Derrick to confirm its usage (or paste `--help` / the script itself) before finalizing the command. If he's shown the actual usage earlier in the conversation, use exactly that.
3. **The git commit message(s)** — split per Derrick's infra/Hugo separation, which is **enforced by a pre-commit hook** (`tools/git-hooks/pre-commit`), not just a convention: it hard-blocks any commit that stages both `infra/`, `.github/`, `scripts/`, or `tools/` paths *and* `apps/hugo/` paths together. Before drafting a commit message:
   - Only ever propose commit messages scoped to `apps/hugo/` paths for content work from this skill.
   - If Derrick mentions the session also touched infra/scripts/tools files, explicitly call out that those need a **separate commit** and never combine them into one `git add`/`git commit` suggestion.
   - If Derrick's pasted `git status` shows unrelated pending changes mixed in (as happens often — signals files, other in-progress work), suggest staging only the specific new/modified paths for this article, not `git add .` or `git add -A`.

Format as:

```
## Draft: <title>

<article code block>

## Scaffold command
<shell command>

## Commit message
<git commit -m "..." >
```

Then stop and wait — do not proceed to "next steps" or offer to do anything further until Derrick confirms the draft is good or asks for changes.

## Notes

- Ratings are numeric (bourbon/rum use `9.4`-style floats out of 10; beer sometimes uses `"TBD"` as a string placeholder until tasted — match whichever the existing file for that category does).
- Bottled-in-Bond / cask-strength / age-stated details go in the info table, not just prose.
- Smoke session logs are operational/log-style, not review-style — no rating block, but do include a "Lessons Learned" and "Runbook Updates Generated" section if the session produced any.
- Always keep infra and Hugo/content commits separate — this is hook-enforced, not optional (see Step 3).
- Family outing posts are narrative/journal-style like bottle reviews, not operational like smoke sessions — but never include real photo paths or children's names; ages and anonymized images only.
- The `apps/hugo/service/archetypes/` directory is the source of truth for exact field lists per type (`bourbon-bottle.md`, `beer-bottle.md`, `rum-bottle.md`, `kb-article.md`, `recipe.md`, `family-outing.md`) — if Derrick pastes an updated archetype, prefer it over these reference files and flag that the reference file should be updated.
