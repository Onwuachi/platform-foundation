---
title: "sed Cheatsheet"
date: 2026-06-23
description: "Stream editor reference — substitution syntax, in-place editing, delimiter switching, and when sed is the wrong tool."
tags: ["sed", "bash", "cli", "linux", "cheatsheet"]
categories: ["infrastructure", "general"]
summary: "sed patterns used throughout platform builds — with real examples from prometheus.yml, HAProxy, and GitHub Actions."
---
# KB-CLI-001: sed Cheatsheet

**Where this lives:** `content/kb/infrastructure/general/sed-cheatsheet.md`

---

## What sed actually is

`sed` = **S**tream **ED**itor. It reads input **line by line**, applies a
command to each line, and prints the result. It never "knows" about the
whole file at once unless you tell it to — by default it's a one-line-at-a-
time machine. That's the single most important mental model: sed processes
a stream, not a document.

```
file → [sed reads line 1] → applies command → prints result → next line...
```

---

## The command you've used most: substitution

```bash
sed 's/OLD/NEW/' file
```

Breaking down `s/OLD/NEW/`:
- `s` = substitute
- First `/.../ ` = pattern to find (supports regex)
- Second `/.../ ` = replacement text
- No trailing flag = replace **only the first match per line**

**The flag you actually want most of the time: `g` (global)**

```bash
sed 's/OLD/NEW/g' file
```
Without `g`, a line with `OLD...OLD` only replaces the first one. This is
the #1 sed mistake — forgetting `g` and wondering why only half your matches
changed.

---

## `-i` — edit the file in place

This is what you've been using throughout this session:

```bash
sed -i 's/OLD/NEW/g' file.yml
```

Without `-i`, sed only prints the result to your terminal — **the file
itself is untouched**. This is actually useful for previewing a change
safely before committing to it:

```bash
sed 's/OLD/NEW/g' file.yml          # preview only, file unchanged
sed -i 's/OLD/NEW/g' file.yml       # now actually edit the file
```

**Always preview risky substitutions first without `-i`.**

---

## Real examples from this session

**1. Standardizing scrape target IPs in prometheus.yml:**
```bash
sed -i 's/172.17.0.1:9115/127.0.0.1:9115/g' prometheus.yml
```
Find `172.17.0.1:9115`, replace every occurrence with `127.0.0.1:9115`.

**2. Fixing a file path (note the escaped slashes and escaped special chars):**
```bash
sed -i 's|/etc/prometheus/rules/\*\.yml|/opt/prometheus/rules/*.yml|g' prometheus.yml
```
Here we used `|` instead of `/` as the delimiter — because the pattern
*itself* contains `/` characters (file paths). If you used `/` as the
delimiter here, every `/` in the path would need escaping (`\/etc\/...`),
which gets unreadable fast. **sed lets you pick any delimiter** — `|`, `#`,
`,`, anything not in your pattern — to avoid this. Also note `\*` and `\.` —
in regex, `*` and `.` are special characters (`.` = any character, `*` =
"zero or more of the previous thing"), so to match them *literally* you
escape them with `\`.

**3. Updating GitHub Actions variable names:**
```bash
sed -i 's/vars\.S3_BUCKET}}/vars.S3_BUCKET_ONWUA_PORTFOLIO_SITE}}/g' deploy-portfolio.yml
```
The `\.` before `S3_BUCKET` escapes the literal dot (`vars.S3_BUCKET`) so
sed doesn't interpret it as "any character."

---

## The four delimiter rule

```bash
sed 's/path/to/file/new'      # BREAKS — sed sees 4 fields, not 2
sed 's|path/to/file|new|'     # WORKS — | as delimiter, / is just text
```

**Rule of thumb:** if your pattern or replacement contains `/`, switch the
delimiter to something that doesn't appear in either side — `|`, `#`, `~`,
`,` are common choices.

---

## Special regex characters you must escape to match literally

| Character | Regex meaning | To match literally |
|---|---|---|
| `.` | any single character | `\.` |
| `*` | zero or more of previous | `\*` |
| `/` | (only special if it's your delimiter) | use a different delimiter, or `\/` |
| `[` `]` | character class | `\[` `\]` |
| `^` | start of line | `\^` |
| `$` | end of line | `\$` |

This is why `install_haproxy.cfg` style paths with dots in filenames need
`\.` — otherwise `domain.map` would also match `domainXmap`, `domain_map`,
anything with one character where the dot is.

---

## Other sed patterns worth knowing

**Delete lines matching a pattern:**
```bash
sed -i '/pattern/d' file
```
Deletes every line containing `pattern`. Used for cleaning up dead config
lines.

**Append text after a matching line:**
```bash
sed -i '/match this line/a\
new line of text' file
```

**Print only lines in a range (like grep but line-number aware):**
```bash
sed -n '10,20p' file
```
`-n` suppresses normal output, `10,20p` prints only lines 10-20.

**Multiple substitutions in one command (semicolon-separated):**
```bash
sed -i 's/foo/bar/g; s/baz/qux/g' file
```

---

## When sed isn't the right tool

sed is line-based and doesn't understand file structure (YAML nesting,
JSON, HCL blocks). For anything beyond "replace this exact text," you risk
corrupting structured files. That's exactly what happened with the
malformed `prometheus.yml` node job earlier — a `sed` edit (or a bad
copy/paste) left an orphaned `ec2_sd_configs:` key with no parent. For
structural changes to YAML/JSON/HCL, edit by hand in an editor (`vi`) or use
a tool that understands the format (`yq` for YAML, `jq` for JSON).

**Rule of thumb:** sed for single-line text substitution. Editor or
format-aware tool for anything touching structure, indentation, or nesting.

---

## Quick reference table

| Goal | Command |
|---|---|
| Replace first match per line | `sed 's/old/new/' file` |
| Replace all matches per line | `sed 's/old/new/g' file` |
| Edit file in place | `sed -i 's/old/new/g' file` |
| Preview without editing | `sed 's/old/new/g' file` (no `-i`) |
| Use different delimiter | `sed 's|old|new|g' file` |
| Delete matching lines | `sed -i '/pattern/d' file` |
| Print line range only | `sed -n '10,20p' file` |
| Chain multiple edits | `sed -i 's/a/b/g; s/c/d/g' file` |
| Match literal dot | `sed 's/file\.txt/x/' ` |
| Match literal asterisk | `sed 's/\*/x/'` |

---

## The diagnostic command you ran this session

```bash
diff main.tf main.tf-bak
```

Not sed, but related — `diff` compares two files line by line and shows
what changed. `<` lines are from the first file (`main.tf`), `>` lines are
from the second (`main.tf-bak`). This is how we discovered the CloudFront
Function additions never actually landed in your edited file — the diff
showed comment-only changes and one unrelated policy addition, but no
`aws_cloudfront_function` block.

```bash
diff file1 file2
# <  = only in file1
# >  = only in file2
# matching lines aren't shown at all
```
