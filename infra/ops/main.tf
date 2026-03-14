##############################
# Read AMI from SSM (Packer writes it)
##############################
data "aws_ssm_parameter" "ops_ami" {
  name = "/devopslab/ami/ops/latest"
}

##############################
# EC2 Instance
##############################
resource "aws_instance" "ops" {
  ami                         = data.aws_ssm_parameter.ops_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.ops_sg_id]
  iam_instance_profile        = var.iam_instance_profile
  key_name                    = var.key_name
  associate_public_ip_address = true
  
  ################################
  # Root Volume
  ################################
  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  ################################
  # Prometheus Data Volume
  ################################
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  ################################
  # User Data
  ################################
  user_data = <<-EOT
#!/bin/bash
set -euo pipefail

LOG=/var/log/ops-user-data.log
exec > >(tee -a "$LOG") 2>&1

################################
# Setup/Attach Prometheus Data Volume
################################

DEVICE="/dev/nvme1n1"
MOUNT_POINT="/opt/prometheus/data"

for i in {1..10}; do
  if lsblk | grep -q nvme1n1; then
    break
  fi
  echo "Waiting for data volume..."
  sleep 3
done

if ! blkid $DEVICE; then
  echo "Formatting Prometheus data volume..."
  mkfs.xfs $DEVICE
fi

mkdir -p $MOUNT_POINT

if ! grep -q "$MOUNT_POINT" /etc/fstab; then
  UUID=$(blkid -s UUID -o value $DEVICE)
  echo "UUID=$UUID  $MOUNT_POINT  xfs  defaults,nofail  0  2" >> /etc/fstab
fi

mount -a
chown -R 65534:65534 $MOUNT_POINT

######

echo "=== OPS bootstrap start ==="

################################
# Stop HAProxy (standalone needs :80)
################################
systemctl stop haproxy || true

################################
# Wait for DNS / network
################################
sleep 10


################################
# One-time cert issuance (standalone)  (*********right now using  --staging  but remove when actually in production****************)
################################
if [ ! -f /etc/letsencrypt/live/onwuachi.com/fullchain.pem ]; then
  systemctl stop haproxy || true

  certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email admin@onwuachi.com \
    -d onwuachi.com \
    -d www.onwuachi.com || true
    --staging || true

  systemctl start haproxy || true
fi


################################
# Build HAProxy PEM (atomic)
################################
cat \
  /etc/letsencrypt/live/onwuachi.com/fullchain.pem \
  /etc/letsencrypt/live/onwuachi.com/privkey.pem \
  > /etc/haproxy/certs/onwuachi.com.pem

chmod 600 /etc/haproxy/certs/onwuachi.com.pem

################################
# Platform API runtime config
################################
mkdir -p /etc/platform

cat >/etc/platform/api.env <<EOF
IMAGE_URI=${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/api:latest
PORT=3000
NODE_ENV=production
EOF

aws ecr get-login-password --region ${var.aws_region} \
 | docker login --username AWS --password-stdin \
   ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

systemctl daemon-reexec
systemctl start ops.target

################################
# Validate & start HAProxy
################################
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl start haproxy

######## Pushgateway 
#######################
echo "Waiting for Pushgateway..."

for i in {1..20}; do
  if curl -sf http://localhost:9091/-/ready >/dev/null; then
    echo "Pushgateway ready"
    break
  fi
  sleep 3
done

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AMI_ID=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

cat <<EOF | curl --data-binary @- http://localhost:9091/metrics/job/deploy
deploy_event{service="platform",env="${var.environment}",instance="$INSTANCE_ID",ami="$AMI_ID",region="$REGION"} 1
EOF

###############################
echo "=== OPS bootstrap complete ==="
EOT

  user_data_replace_on_change = true

  tags = {
    Name        = var.ec2_name
    Environment = var.environment
    Owner       = "derrick"
    Role        = "ops"
    BuiltBy     = "packer"
  }
}

##############################
# Elastic IP
##############################
resource "aws_eip" "ops" {
  tags = { Name = "ops-eip" }
}

resource "aws_eip_association" "ops" {
  instance_id   = aws_instance.ops.id
  allocation_id = aws_eip.ops.id
}

##############################
# Route53 records
##############################
data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.root_domain
  type    = "A"
  ttl     = 60
  records = [aws_eip.ops.public_ip]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.root_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_eip.ops.public_ip]
}


