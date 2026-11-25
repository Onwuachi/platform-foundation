#!/usr/bin/env bash
set -euo pipefail
ACCT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://dop-lab-${ACCT}-data" --recursive 2>/dev/null || true
aws cloudformation delete-stack --stack-name dop-lab-root
aws cloudformation wait stack-delete-complete --stack-name dop-lab-root
echo "Leftovers tagged Project=dop-lab (should be empty):"
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=dop-lab \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
