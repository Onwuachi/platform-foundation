#!/bin/bash
set -euo pipefail

ACTION="$1"
INSTANCE_NAME="${2:-ops-01}"

if [[ "$ACTION" != "disable" && "$ACTION" != "enable" ]]; then
  echo "Usage: $0 <disable|enable> [instance-name]"
  echo "  disable — opens /private /family /secure (no auth prompt)"
  echo "  enable  — restores the auth prompt"
  exit 1
fi

if [[ "$ACTION" == "disable" ]]; then
  SED_CMD='sudo sed -i "s|^  http-request auth realm|  # http-request auth realm|" /etc/haproxy/haproxy.cfg'
  echo "Disabling private-area auth on $INSTANCE_NAME..."
else
  SED_CMD='sudo sed -i "s|^  # http-request auth realm|  http-request auth realm|" /etc/haproxy/haproxy.cfg'
  echo "Re-enabling private-area auth on $INSTANCE_NAME..."
fi

CHECK_AND_RELOAD='sudo haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/ && sudo systemctl reload haproxy && echo RELOAD_OK'

# Build the SSM parameters JSON with python — sidesteps AWS CLI shorthand
# parser choking on nested double quotes inside the shell commands.
PARAMS_FILE=$(mktemp)
trap 'rm -f "$PARAMS_FILE"' EXIT

SED_CMD="$SED_CMD" RELOAD_CMD="$CHECK_AND_RELOAD" python3 -c "
import json, os
print(json.dumps({'commands': [os.environ['SED_CMD'], os.environ['RELOAD_CMD']]}))
" > "$PARAMS_FILE"

CMD_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=$INSTANCE_NAME" \
  --parameters "$(cat "$PARAMS_FILE")" \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $CMD_ID — waiting for result..."
sleep 5

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" || true

aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "{Status:Status,StdOut:StandardOutputContent,StdErr:StandardErrorContent}" \
  --output table
