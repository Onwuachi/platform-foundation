#!/bin/bash
set -euo pipefail

python3 -c "
import json, glob
from datetime import datetime, timezone

files = glob.glob('$HOME/.aws/sso/cache/*.json')
tokens = []
for f in files:
    d = json.load(open(f))
    if 'expiresAt' in d and 'accessToken' in d:
        exp = datetime.fromisoformat(d['expiresAt'].replace('Z', '+00:00'))
        tokens.append((exp, d['expiresAt']))

if not tokens:
    print('No cached SSO token found — run: aws sso login --profile platform-foundation')
else:
    exp, raw = max(tokens, key=lambda t: t[0])
    remaining = exp - datetime.now(timezone.utc)
    mins = int(remaining.total_seconds() / 60)
    if mins < 0:
        print(f'No valid token — most recent cached one expired {abs(mins)} min ago ({raw})')
    elif mins < 15:
        print(f'⚠️  Expires in {mins} min ({raw})')
    else:
        print(f'✅ Valid — {mins} min remaining ({raw})')
"
