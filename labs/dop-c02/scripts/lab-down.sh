#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ACCT=$(aws sts get-caller-identity --query Account --output text)

if aws cloudformation describe-stack-set --stack-set-name dop-lab-marker >/dev/null 2>&1; then
  N=$(aws cloudformation list-stack-instances --stack-set-name dop-lab-marker \
    --query 'length(Summaries)' --output text)
  if [ "$N" -gt 0 ]; then
    OP=$(aws cloudformation delete-stack-instances --stack-set-name dop-lab-marker \
      --accounts "$ACCT" --regions us-east-1 us-east-2 --no-retain-stacks \
      --query OperationId --output text)
    "$HERE/ss-wait.sh" "$OP"
  fi
  aws cloudformation delete-stack-set --stack-set-name dop-lab-marker
fi

aws s3 rm "s3://dop-lab-${ACCT}-data" --recursive 2>/dev/null || true
aws cloudformation delete-stack --stack-name dop-lab-root
aws cloudformation wait stack-delete-complete --stack-name dop-lab-root

aws cloudformation delete-stack --stack-name dop-lab-stackset-roles
aws cloudformation wait stack-delete-complete --stack-name dop-lab-stackset-roles

for R in us-east-1 us-east-2; do
  echo "Leftovers tagged Project=dop-lab in $R (should be empty):"
  aws resourcegroupstaggingapi get-resources --region "$R" \
    --tag-filters Key=Project,Values=dop-lab \
    --query 'ResourceTagMappingList[].ResourceARN' --output text
done
