#!/usr/bin/env bash
set -euo pipefail

echo "======================================="
echo " PLATFORM STARTUP"
echo "======================================="

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=ops" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

echo "Starting instance..."

aws ec2 start-instances --instance-ids $IDS >/dev/null

echo "Waiting for instance..."

aws ec2 wait instance-running --instance-ids $IDS

echo "Waiting for SSM..."

sleep 20

echo "Running rehydrate..."

COMMAND_ID=$(aws ssm send-command \
  --targets "Key=tag:Role,Values=ops" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="sudo /usr/local/bin/platform-rehydrate.sh" \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $COMMAND_ID"

echo "Waiting for rehydrate..."

sleep 15

########################################
# VALIDATION
########################################

echo
echo "==> Validating HAProxy"

aws ssm send-command \
  --targets "Key=tag:Role,Values=ops" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="systemctl is-active haproxy"

echo
echo "==> Validating containers"

aws ssm send-command \
  --targets "Key=tag:Role,Values=ops" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="docker ps"

echo
echo "==> Validating routing"

aws ssm send-command \
  --targets "Key=tag:Role,Values=ops" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="curl -k -I https://onwuachi.com"

echo
echo "======================================="
echo " PLATFORM START COMPLETE"
echo "======================================="
