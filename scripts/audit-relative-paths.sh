#!/bin/bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

echo "Scanning scripts/ and tools/ for un-anchored relative path assignments..."
echo "(heuristic — flags for review, not definitive bugs)"
echo ""

python3 -c "
import re, glob

pattern = re.compile(r'^\s*([A-Z_][A-Z0-9_]*)=\"([a-zA-Z][a-zA-Z0-9_./-]*/[a-zA-Z0-9_./-]*)\"')

files = glob.glob('scripts/**/*.sh', recursive=True) + glob.glob('tools/**/*.sh', recursive=True)
hits = 0

for path in sorted(files):
    with open(path, errors='ignore') as f:
        for lineno, line in enumerate(f, 1):
            m = pattern.match(line)
            if m:
                varname, value = m.groups()
                if '\$(' in line or '\${' in line.split('=',1)[1][:1]:
                    continue
                print(f'{path}:{lineno}: {varname}=\"{value}\"  <- relative, not anchored to repo root')
                hits += 1

print()
if hits == 0:
    print('No suspicious un-anchored relative paths found.')
else:
    print(f'{hits} line(s) worth a manual look — not all are bugs, but each should be confirmed intentional.')
"
