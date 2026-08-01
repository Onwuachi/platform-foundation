#!/bin/bash
set -e

EC2_PUBLIC_IP=$1
SSH_KEY="~/.ssh/onwua_key.pem"

if [ -z "$EC2_PUBLIC_IP" ]; then
  echo "Usage: $0 <EC2_PUBLIC_IP>"
  exit 1
fi

echo "🛑 Stopping HAProxy and Nginx on Onwuachi web server ($EC2_PUBLIC_IP)..."

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/onwua_key.pem ubuntu@"$EC2_PUBLIC_IP" <<'EOF'
  set -e
  sudo systemctl stop haproxy nginx
  echo "→ Services stopped."
EOF

echo "🧊 Web services stopped successfully."
