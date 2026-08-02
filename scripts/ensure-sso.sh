#!/bin/bash
set -euo pipefail

if ! aws sts get-caller-identity --profile "${AWS_PROFILE:-platform-foundation}" &>/dev/null; then
  echo "⚠️  SSO session expired or missing. Logging in..."
  aws sso login --profile "${AWS_PROFILE:-platform-foundation}"
  echo "✅ SSO login complete."
else
  echo "✅ SSO session active."
fi
