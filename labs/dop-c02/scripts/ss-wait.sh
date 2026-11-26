#!/usr/bin/env bash
set -euo pipefail
OP="$1"
while true; do
  S=$(aws cloudformation describe-stack-set-operation \
    --stack-set-name dop-lab-marker --operation-id "$OP" \
    --query 'StackSetOperation.Status' --output text)
  echo "status: $S"
  case "$S" in
    RUNNING|QUEUED|STOPPING) sleep 5 ;;
    *) break ;;
  esac
done
