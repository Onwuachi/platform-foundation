#!/bin/bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

./scripts/ensure-sso.sh

cd infra/infra_audit/cli
python infra_audit_cli.py bill --days "${1:-31}"
