#!/bin/bash
set -euo pipefail

ACTION="$1"
INSTANCE_NAME="${2:-ops-01}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <start|stop|upgrade> [instance-name]"
  exit 1
fi

case "$ACTION" in
  start)
    COMMAND="sudo systemctl start haproxy docker && sudo systemctl status haproxy docker --no-pager"
    ;;
  stop)
    COMMAND="sudo systemctl stop haproxy docker && echo Services stopped."
    ;;
  upgrade)
    COMMAND="sudo apt update -y && sudo apt upgrade -y && sudo systemctl restart haproxy docker && sudo systemctl status haproxy docker --no-pager"
    ;;
  *)
    echo "Invalid action: $ACTION (expected start, stop, or upgrade)"
    exit 1
    ;;
esac

echo "Running '$ACTION' on instances tagged Name=$INSTANCE_NAME via SSM..."

CMD_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=$INSTANCE_NAME" \
  --parameters "commands=[\"$COMMAND\"]" \
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
