#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)/labs/dop-c02"
REGION=us-east-1
ACCT=$(aws sts get-caller-identity --query Account --output text)
ART="dop-lab-artifacts-${ACCT}"
STACK=dop-lab-root
aws s3api head-bucket --bucket "$ART" 2>/dev/null || aws s3 mb "s3://${ART}" --region "$REGION"
aws cloudformation package --template-file cfn/root.yaml \
  --s3-bucket "$ART" --s3-prefix lab1 \
  --output-template-file /tmp/dop-lab-root.packaged.yaml
aws cloudformation deploy --template-file /tmp/dop-lab-root.packaged.yaml \
  --stack-name "$STACK" --capabilities CAPABILITY_IAM \
  --tags Project=dop-lab "$@"
aws cloudformation describe-stacks --stack-name "$STACK" \
  --query 'Stacks[0].Outputs' --output table
