# Bottle Review Template (Bourbon / Rum / Scotch / Beer)

Source: extracted from `content/private/bourbon/bottles/heaven-hill-7-year-bib.md`,
`content/private/beer/bottles/bells-citrus-hopslam.md`, and the blank scaffold
`content/private/rum/bottles/appleton-estate-15-year.md`.

Format: **TOML** (`+++` delimiters), not YAML.

## Frontmatter — spirits (bourbon/rum/scotch)

```toml
+++
title = "Full Bottle Name"
date = 2026-07-20T10:15:00-05:00
draft = false

type = "bourbon-bottle"   # or "rum-bottle", "scotch-bottle"

image = "/images/bourbon/slug-name.png"

brand = "Brand Name"
expression = "Expression Name"

distillery = "Distillery Name"
producer = "Producer Name"

classification = "Kentucky Straight Bourbon Whiskey"   # style/classification

proof = 100
age = "7 Years"        # or "" if NAS (no age statement)

msrp = "$49.99"
paid = "$38.99"

availability = "Generally Available"   # or "Allocated", "Limited Release", etc.

batch = ""              # batch/barrel number if applicable

rating = 9.4             # float out of 10, or 0 if not yet rated

shelf_role = "Benchmark Bourbon"   # optional descriptor tag

would_buy_again = true   # boolean, spirits only

tags = [
  "tag one",
  "tag two"
]

categories = ["Bourbon Bottles"]   # or "Rum Bottles", "Scotch Bottles"
+++
```

## Frontmatter — beer

```toml
+++
title = "Beer Name"
date = 2026-08-22T09:00:00-05:00
draft = false

type = "beer-bottle"

image = "/images/beer/slug-name.png"

brewery = "Brewery Name"
style = "Double India Pale Ale (DIPA)"
country = "United States"
city = "City, State"

abv = "9%"
ibu = "Unknown"          # or numeric if known
package = "4 x 16 oz Cans"

msrp = "$12.99"
paid = "$12.99"

rating = "TBD"            # string placeholder until tasted, or numeric once rated

tags = [
  "beer",
  "style tag"
]

categories = ["Beer Bottles"]
+++
```

**Field differences by category:**
- Spirits use `distillery`/`producer`/`proof`/`age`/`classification`/`would_buy_again`
- Beer uses `brewery`/`style`/`country`/`city`/`abv`/`ibu`/`package` — no `would_buy_again` field
- Leave any unknown field blank (`""`) or `0`/`"TBD"` rather than guessing — Derrick's own blank scaffolds do this

## Body structure (all categories, in order)

```markdown
# Why I Bought It

[First-person narrative — why this bottle, what prompted the purchase or interest.
Ends with <!--more--> after the first section for spirits, optional for beer.]

<!--more-->

# Bottle Information   (spirits)  /  # Beer Information   (beer)

| Property | Value |
|-----------|-------|
| Brand/Brewery | |
| Expression/Style | |
| Distillery/Country | |
| ... | |

---

# About the Whiskey   (spirits only — optional context section, e.g. Bottled-in-Bond
explanation, mash bill notes, production method. Omit for beer.)

---

# Appearance

[Color, viscosity, legs. "Not fully documented yet." is an acceptable placeholder
if not yet observed — matches beer example.]

---

# Nose   (spirits)  /  # Aroma   (beer)

[Bulleted list of notes, then narrative.]

---

# Palate   (spirits)  /  # Flavor   (beer)

[How notes arrive/transition — spirits often describe layering. Bulleted list + narrative.]

---

# Finish

[Length, how it fades, lingering notes.]

---

# Mouthfeel

[Body, texture, carbonation for beer.]

---

# What I Liked

- [bulleted list]

---

# What I'd Change

[Bulleted list, or narrative if "still evaluating" / minimal critique.]

---

# Comparison Notes   (spirits — optional, when comparing to other bottles owned)

## Compared to X
[short paragraph]

---

# Food Pairings

- [bulleted list]

---

# Shelf Role   (spirits)  /  # Where It Fits   (beer)

[Where this bottle sits relative to others in the collection.]

---

# Final Thoughts

[Closing narrative paragraph(s).]

---

# Rating   (spirits)  /  # Verdict   (beer — no separate Rating header, folds into Verdict)

**X.X / 10**   (spirits — bold, large)

[One-line summary descriptor.]

## Verdict

✅ Buy Again: **Yes/No/Likely**

🥃 Backup Bottle: **Always/Sometimes/No**   (spirits)

🏆 Best For: **description**

🥇 Personal Tier: **S/A/B/C Tier**

📦 Collection Status: **Permanent Shelf Bottle / Comparison Beer / etc.**
```

For beer, `Verdict` is a `##` subsection with slightly different labels: `Buy Again`, `Best Season`, `Personal Tier`, `Collection Status`, and sometimes a closing `Question Answered` Q&A pair if the review was framed as investigating something (e.g. "how does this compare to the original?").

## Notes

- Emoji in the verdict block (✅🥃🏆🥇📦) are used consistently in spirits reviews — keep them.
- Voice is first-person, reflective, comparison-heavy. Not a formal tasting-note format — reads like a personal journal entry with structure.
- `draft = true` on a freshly scaffolded blank file (per the Appleton Estate example) — Derrick flips to `false` when the review is complete. Default new drafts to `draft = false` only if Derrick says the review is finished; otherwise leave `draft = true` and mention it.
