#!/bin/bash
set -euo pipefail

python3 -c "
import json, glob
from datetime import datetime, timezone

files = glob.glob('$HOME/.aws/sso/cache/*.json')
found = False
for f in files:
    d = json.load(open(f))
    if 'expiresAt' in d and 'accessToken' in d:
        found = True
        exp = datetime.fromisoformat(d['expiresAt'].replace('Z', '+00:00'))
        remaining = exp - datetime.now(timezone.utc)
        mins = int(remaining.total_seconds() / 60)
        if mins < 0:
            print(f'❌ Expired {abs(mins)} min ago ({d[\"expiresAt\"]})')
        elif mins < 15:
            print(f'⚠️  Expires in {mins} min ({d[\"expiresAt\"]})')
        else:
            print(f'✅ Valid — {mins} min remaining ({d[\"expiresAt\"]})')
if not found:
    print('No cached SSO token found — run: aws sso login --profile platform-foundation')
"
