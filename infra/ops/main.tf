##############################
# LOCALS (🔥 TAG ENFORCEMENT)
##############################
locals {
  common_tags = {
    Environment = var.environment
    Owner       = "derrick"
    ManagedBy   = "terraform"
    Project     = "platform"
  }
}

##############################
# Read AMI from SSM
##############################
data "aws_ssm_parameter" "ops_ami" {
  name = "/devopslab/ami/ops/latest"
}

##############################
# S3 Platform State
##############################
resource "aws_s3_bucket" "platform_state" {
  bucket = "platform-api-services"

  tags = merge(local.common_tags, {
    Name = "platform-state"
  })
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
# S3 - Hugo Artifacts
##############################
resource "aws_s3_bucket" "hugo_artifacts" {
  bucket = "onwuachi-hugo-artifacts"

  tags = merge(local.common_tags, {
    Name = "hugo-artifacts"
  })
}

##############################
# hugo_artifacts Versioning
##############################
resource "aws_s3_bucket_versioning" "hugo_artifacts" {
  bucket = aws_s3_bucket.hugo_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

##############################
# hugo_artifacts Block Public Access (IMPORTANT)
##############################
resource "aws_s3_bucket_public_access_block" "hugo_artifacts" {
  bucket = aws_s3_bucket.hugo_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################
# hugo_artifacts Lifecycle (keep it clean)
##############################
resource "aws_s3_bucket_lifecycle_configuration" "hugo_artifacts" {
  bucket = aws_s3_bucket.hugo_artifacts.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 7
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
# EC2 Instance (STATELESS)
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
  # Prometheus Volume (Ephemeral)
  ################################
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  ################################
  # USER DATA (DATA PLANE ONLY)
  ################################
  user_data = <<-EOT
#!/bin/bash
set -euo pipefail

LOG=/var/log/ops-user-data.log
exec > >(tee -a "$LOG") 2>&1

echo "=== OPS bootstrap start ==="

################################
# VOLUME DETECTION
################################

get_device_by_size() {
  TARGET_SIZE=$1
  TOLERANCE=104857600

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
    sleep 3
  done

  if ! file -s "$DEVICE" | grep -q filesystem; then
    mkfs.xfs "$DEVICE"
  fi

  mkdir -p "$MOUNT"

  if ! grep -q "$MOUNT" /etc/fstab; then
    UUID=$(blkid -s UUID -o value "$DEVICE")
    echo "UUID=$UUID $MOUNT xfs defaults,nofail 0 2" >> /etc/fstab
  fi
}

PROM_DEVICE=$(get_device_by_size 16106127360)
PLATFORM_DEVICE=$(get_device_by_size 5368709120 || true)

if [ -z "$PLATFORM_DEVICE" ]; then
  echo "⚠️ Platform device not found, skipping mount"
else
  setup_volume "$PLATFORM_DEVICE" /opt/platform
fi

setup_volume "$PROM_DEVICE" /opt/prometheus/data

if [ -n "$PLATFORM_DEVICE" ]; then
  setup_volume "$PLATFORM_DEVICE" /opt/platform
fi

mount -a

chown -R 65534:65534 /opt/prometheus/data
chown -R ubuntu:ubuntu /opt/platform
chmod -R 775 /opt/platform

################################
# PLATFORM SYNC
################################

mkdir -p /opt/platform/services

aws s3 sync \
  s3://platform-api-services/platform/services \
  /opt/platform/services \
  || true

################################
# START PLATFORM
################################

echo "Running rehydrate..."
/usr/local/bin/platform-rehydrate.sh


systemctl daemon-reexec
systemctl start haproxy
systemctl start hugo
systemctl start ops.target

echo "=== OPS bootstrap complete ==="
EOT

  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name  = var.ec2_name
    Role  = "ops"
    BuiltBy = "packer"
  })
}

##############################
# 🔥 PERSISTENT PLATFORM VOLUME
##############################
resource "aws_ebs_volume" "platform" {
  availability_zone = aws_instance.ops.availability_zone
  size              = 5
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name    = "platform-persistent"
    Purpose = "platform-state"
    Persist = "true"
  })
}

resource "aws_volume_attachment" "platform" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.platform.id
  instance_id = aws_instance.ops.id
}

##############################
# Elastic IP
##############################
resource "aws_eip" "ops" {
  tags = merge(local.common_tags, {
    Name = "ops-eip"
  })
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

