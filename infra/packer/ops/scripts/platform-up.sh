#!/usr/bin/env bash
set -e

echo "Starting platform..."

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=ops" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

aws ec2 start-instances --instance-ids $IDS

echo "Waiting for instance..."

sleep 30

echo "Rehydrating..."

aws ssm send-command \
  --targets "Key=tag:Role,Values=ops" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="sudo /usr/local/bin/platform-rehydrate.sh"

echo "✅ Platform started"