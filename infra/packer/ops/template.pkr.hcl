packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

############################
# Variables
############################
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ami_name" {
  type    = string
  default = "ops-platform-observability"
}

variable "ami_keep_last" {
  type    = number
  default = 2
}

############################
# Source AMI
############################
source "amazon-ebs" "ops" {
  region                      = var.region
  instance_type               = "t3.small"
  ssh_username                = "ubuntu"
  associate_public_ip_address = true

  ami_name        = "${var.ami_name}-{{timestamp}}"
  force_deregister = true
  force_delete_snapshot = true

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }

    owners      = ["099720109477"]
    most_recent = true
  }
}

############################
# Build
############################
build {
  name    = "ops-image"
  sources = ["source.amazon-ebs.ops"]

  ################################
  # File provisioning
  ################################
  provisioner "file" {
    source      = "systemd"
    destination = "/tmp/systemd"
  }

  ################################
  # Shell provisioning
  ################################
  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    scripts = [
      "scripts/install_base.sh",
      "scripts/install_swap.sh",
      "scripts/install_haproxy.sh",
      "scripts/install_dummy_cert.sh",
      "scripts/install_certbot.sh",
      "scripts/install_renew_hook.sh",
      "scripts/install_blackbox_exporter.sh",
      "scripts/systemd.sh",
      "scripts/docker.sh",
      "scripts/hugo.sh"
    ]
  }


################################
# Hugo Build (Baked into AMI)
################################
#provisioner "shell" {
#  execute_command = "sudo -E bash '{{ .Path }}'"
#  script = "scripts/hugo.sh"
#}

############ Phase 3 – Observability ############

################################
# Install Node Exporter (host binary)
################################
provisioner "shell" {
  execute_command = "sudo -E bash '{{ .Path }}'"
  script = "scripts/install_node_exporter.sh"
}

################################
# Create Prometheus directories (root-owned)
################################
provisioner "shell" {
  execute_command = "sudo -E bash '{{ .Path }}'"
  script = "scripts/install_prometheus_dirs.sh"
}

################################
# Create Grafana directories
################################
provisioner "shell" {
  execute_command = "sudo -E bash '{{ .Path }}'"
  script = "scripts/install_grafana_dirs.sh"
}

################################
# Upload Prometheus config to /tmp (avoid SCP permission issue)
################################
provisioner "file" {
  source      = "files/prometheus.yml"
  destination = "/tmp/prometheus.yml"
}

provisioner "file" {
  source      = "files/rules"
  destination = "/tmp/rules"
}

################################
# Move Prometheus config into protected directory
################################
provisioner "shell" {
  inline = [
    "sudo mv /tmp/prometheus.yml /opt/prometheus/prometheus.yml",
    "sudo mkdir -p /opt/prometheus/rules",
    "sudo mv /tmp/rules/* /opt/prometheus/rules/",
    "sudo rm -rf /tmp/rules"
  ]
}

################################
# Upload systemd units (safe location)
################################
provisioner "file" {
  source      = "systemd/node_exporter.service"
  destination = "/tmp/node_exporter.service"
}

provisioner "file" {
  source      = "systemd/prometheus.service"
  destination = "/tmp/prometheus.service"
}

################################
# Move systemd units into place
################################
provisioner "shell" {
  inline = [
    "sudo mv /tmp/node_exporter.service /etc/systemd/system/node_exporter.service",
    "sudo mv /tmp/prometheus.service /etc/systemd/system/prometheus.service",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable node_exporter.service",
    "sudo systemctl enable prometheus.service",
    "sudo systemctl enable grafana.service"
  ]
}


############
# blackbox_exporter provisioning
##############
provisioner "file" {
  source      = "files/blackbox.yml"
  destination = "/tmp/blackbox.yml"
}

####Move blackbox_exporter config + service

provisioner "file" {
  source      = "systemd/blackbox-exporter.service"
  destination = "/tmp/blackbox-exporter.service"
}

provisioner "shell" {
  inline = [
    "sudo mv /tmp/blackbox.yml /opt/blackbox/blackbox.yml",
    "sudo mv /tmp/blackbox-exporter.service /etc/systemd/system/blackbox-exporter.service",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable blackbox-exporter.service"
  ]
}




  ################################
  # Post-Processors
  ################################
  post-processors {

    post-processor "manifest" {
      output = "manifest.json"
    }

    # Update SSM with latest AMI
    post-processor "shell-local" {
      inline = [
        "AMI_ID=$(jq -r '.builds[-1].artifact_id' manifest.json | cut -d':' -f2)",
        "if [ -z \"$AMI_ID\" ]; then echo 'ERROR: AMI_ID empty' && exit 1; fi",
        "echo 'New AMI:' $AMI_ID",
        "aws ssm put-parameter --name /devopslab/ami/ops/latest --type String --value \"$AMI_ID\" --overwrite --region ${var.region}"
      ]
    }

    # 🔥 Automatic AMI Cleanup
    post-processor "shell-local" {
      inline = [
        "echo 'Pruning old AMIs...'",
        "AMI_LIST=$(aws ec2 describe-images --owners self --region ${var.region} --filters Name=name,Values='${var.ami_name}-*' --query 'Images | sort_by(@,&CreationDate)[].ImageId' --output text)",
        "AMI_COUNT=$(echo \"$AMI_LIST\" | wc -w)",
        "KEEP=${var.ami_keep_last}",
        "DELETE_COUNT=$((AMI_COUNT-KEEP))",
        "if [ \"$DELETE_COUNT\" -le 0 ]; then echo 'Nothing to prune'; exit 0; fi",
        "OLD_AMIS=$(echo \"$AMI_LIST\" | awk '{for(i=1;i<=NF-'$KEEP';i++) printf $i\" \"}')",
        "for AMI in $OLD_AMIS; do",
        "  echo 'Deregistering' $AMI",
        "  SNAPSHOT_ID=$(aws ec2 describe-images --image-ids $AMI --region ${var.region} --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text)",
        "  aws ec2 deregister-image --image-id $AMI --region ${var.region}",
        "  if [ \"$SNAPSHOT_ID\" != \"None\" ]; then",
        "    echo 'Deleting snapshot' $SNAPSHOT_ID",
        "    aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID --region ${var.region}",
        "  fi",
        "done"
      ]
    }
  }
}
