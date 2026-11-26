#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CFN="$HERE/../cfn/stackset"
ACCT=$(aws sts get-caller-identity --query Account --output text)

aws cloudformation deploy --template-file "$CFN/roles.yaml" \
  --stack-name dop-lab-stackset-roles --capabilities CAPABILITY_NAMED_IAM \
  --tags Project=dop-lab

if ! aws cloudformation describe-stack-set --stack-set-name dop-lab-marker >/dev/null 2>&1; then
  aws cloudformation create-stack-set --stack-set-name dop-lab-marker \
    --template-body "file://$CFN/marker.yaml" \
    --permission-model SELF_MANAGED \
    --administration-role-arn "arn:aws:iam::${ACCT}:role/AWSCloudFormationStackSetAdministrationRole" \
    --execution-role-name AWSCloudFormationStackSetExecutionRole \
    --tags Key=Project,Value=dop-lab
fi

N=$(aws cloudformation list-stack-instances --stack-set-name dop-lab-marker \
  --query 'length(Summaries)' --output text)
if [ "$N" -eq 0 ]; then
  OP=$(aws cloudformation create-stack-instances --stack-set-name dop-lab-marker \
    --accounts "$ACCT" --regions us-east-1 us-east-2 \
    --operation-preferences RegionConcurrencyType=SEQUENTIAL,RegionOrder=us-east-1,us-east-2,FailureToleranceCount=0,MaxConcurrentCount=1 \
    --query OperationId --output text)
  "$HERE/ss-wait.sh" "$OP"
fi
