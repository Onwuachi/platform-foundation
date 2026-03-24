##############################
# Read AMI from SSM (Packer writes it)
##############################
data "aws_ssm_parameter" "ops_ami" {
  name = "/devopslab/ami/ops/latest"
}

##############################
# Platform-api service state and versioning 
##############################
resource "aws_s3_bucket" "platform_state" {
  bucket = "platform-api-services"

  tags = {
    Name        = "platform-state"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "platform_state" {
  bucket = aws_s3_bucket.platform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "platform_state" {
  bucket = aws_s3_bucket.platform_state.id

  rule {
    id     = "limit-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 3
    }
  }

  rule {
    id     = "cleanup-delete-markers"
    status = "Enabled"

    expiration {
      expired_object_delete_marker = true
    }
  }
}

##############################
# Route53 Zone
##############################
data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
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
  # Prometheus Volume (15GB)
  ################################
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  ################################
  # Platform Volume (5GB, persistent)
  ################################
  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_size           = 5
    volume_type           = "gp3"
    delete_on_termination = false
    encrypted             = true
  }

  ################################
  # USER DATA
  ################################
  user_data = <<-EOT
#!/bin/bash
set -euo pipefail

LOG=/var/log/ops-user-data.log
exec > >(tee -a "$LOG") 2>&1

echo "=== OPS bootstrap start ==="

################################
# VOLUME DETECTION (SAFE)
################################

get_device_by_size() {
  TARGET_SIZE=$1
  TOLERANCE=104857600   # 100MB

  for dev in /dev/nvme*n1; do
    SIZE=$(blockdev --getsize64 "$dev")

    LOWER=$((TARGET_SIZE - TOLERANCE))
    UPPER=$((TARGET_SIZE + TOLERANCE))

    if [ "$SIZE" -ge "$LOWER" ] && [ "$SIZE" -le "$UPPER" ]; then
      echo "$dev"
      return
    fi
  done

  echo "ERROR: No device found for size $TARGET_SIZE"
  exit 1
}

setup_volume () {
  DEVICE=$1
  MOUNT=$2

  for i in {1..10}; do
    [ -e "$DEVICE" ] && break
    echo "Waiting for $DEVICE..."
    sleep 3
  done


  if ! file -s "$DEVICE" | grep -q filesystem; then
    echo "Formatting $DEVICE..."
    mkfs.xfs "$DEVICE"
  else
    echo "$DEVICE already has filesystem, skipping format"
  fi

  mkdir -p "$MOUNT"

  if ! grep -q "$MOUNT" /etc/fstab; then
    UUID=$(blkid -s UUID -o value "$DEVICE")
    echo "UUID=$UUID $MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi
}

PROM_DEVICE=$(get_device_by_size 16106127360)
PLATFORM_DEVICE=$(get_device_by_size 5368709120)

setup_volume "$PROM_DEVICE" /opt/prometheus/data
setup_volume "$PLATFORM_DEVICE" /opt/platform

mount -a
chown -R 65534:65534 /opt/prometheus/data
chown -R ubuntu:ubuntu /opt/platform
chmod -R 775 /opt/platform

################################
# PLATFORM STATE LINK and SYNC
################################

if [ ! -L /etc/platform ]; then
  rm -rf /etc/platform
  ln -s /opt/platform /etc/platform
fi

echo "Platform state:"
ls -R /opt/platform


aws s3 sync s3://platform-api-services/platform/ /opt/platform || true

mkdir -p /opt/platform/services

[ -f /opt/platform/services.list ] || touch /opt/platform/services.list


################################
# Rebuild HAProxy dynamic services from platform state
################################

echo "Cleaning old HAProxy configs..."
rm -f /etc/haproxy/services/*.cfg || true

echo "Rebuilding HAProxy dynamic configs..."

SERVICES_FILE="/opt/platform/services.list"
SERVICES_DIR="/etc/haproxy/services"

mkdir -p "$SERVICES_DIR"

if [ -f "$SERVICES_FILE" ]; then
  while read -r svc; do
    [ -z "$svc" ] && continue

    PORT_FILE="/opt/platform/$${svc}.port"
    
    if [ -f "$PORT_FILE" ]; then
      PORT=$(cat "$PORT_FILE")

    cat > "$SERVICES_DIR/$${svc}.cfg" <<EOF
    backend $${svc}_backend
      http-request replace-path ^/$${svc}/?(.*)$ /\1
      server $${svc}1 127.0.0.1:$${PORT} check
    EOF

      echo "Rebuilt config for $svc → port $PORT"
    fi
  done < "$SERVICES_FILE"
fi

echo "=== OPS bootstrap start ==="

################################
# CERTIFICATE BOOTSTRAP: Stop HAProxy (standalone needs :80)
################################
systemctl stop haproxy || true

sleep 10

if [ ! -f /etc/letsencrypt/live/onwuachi.com/fullchain.pem ]; then

  certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email admin@onwuachi.com \
    -d onwuachi.com \
    -d www.onwuachi.com \
    --deploy-hook "/etc/letsencrypt/renewal-hooks/deploy/haproxy"

fi

################################
# ENABLE AUTO-RENEW
################################

systemctl enable certbot.timer
systemctl start certbot.timer

################################
# PLATFORM CONFIG
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

################################
# START PLATFORM SERVICES
################################

systemctl daemon-reexec
systemctl start ops.target

##################################
# wait
###################################
echo "Waiting for platform services to be ready..."

for i in {1..30}; do
  if curl -sf http://localhost:3000/ready >/dev/null; then
    echo "API ready"
    break
  fi
  sleep 2
done

for i in {1..30}; do
  if curl -sf http://localhost:8080 >/dev/null; then
    echo "Hugo ready"
    break
  fi
  sleep 2
done

################################
# START HAPROXY (after cert exists)
################################

haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl start haproxy


################################
# PLATFORM STATE SYNC Backup
################################
echo "Backing up platform state to S3..."

aws s3 sync /opt/platform s3://platform-api-services/platform/ --delete

################################
# PUSH DEPLOY METRIC
################################

for i in {1..20}; do
  curl -sf http://localhost:9091/-/ready && break
  sleep 3
done

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AMI_ID=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

cat <<EOF | curl --data-binary @- http://localhost:9091/metrics/job/deploy
deploy_event{service="platform",env="${var.environment}",instance="$INSTANCE_ID",ami="$AMI_ID",region="$REGION"} 1
EOF

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
# Route53 Records
##############################
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