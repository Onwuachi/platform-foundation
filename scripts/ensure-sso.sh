#!/bin/bash
set -euo pipefail

if ! aws sts get-caller-identity --profile "${AWS_PROFILE:-platform-foundation}" &>/dev/null; then
  echo "⚠️  SSO session expired or missing. Logging in..."
  aws sso login --profile "${AWS_PROFILE:-platform-foundation}"
  echo "✅ SSO login complete."
else
  echo "✅ SSO session active."

  python3 -c "
import json, glob
from datetime import datetime, timezone
for f in glob.glob('$HOME/.aws/sso/cache/*.json'):
    d = json.load(open(f))
    if 'expiresAt' in d and 'accessToken' in d:
        exp = datetime.fromisoformat(d['expiresAt'].replace('Z', '+00:00'))
        mins_left = (exp - datetime.now(timezone.utc)).total_seconds() / 60
        if mins_left < 15:
            print(f'⚠️  Token expires in {int(mins_left)} min — re-login soon if this run is long')
"
fi
