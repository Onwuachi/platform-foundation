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

  ami_name              = "${var.ami_name}-{{timestamp}}"
  force_deregister      = true
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
      "scripts/install_monitoring_users.sh",
      "scripts/install_base.sh",
      "scripts/install_swap.sh",
      "scripts/install_haproxy.sh",
      "scripts/install_dummy_cert.sh",
      "scripts/install_certbot.sh",
      "scripts/install_blackbox_exporter.sh",
      "scripts/docker.sh",
      "scripts/systemd.sh",
      "scripts/install_pushgateway.sh",
      "scripts/hardening.sh"
    ]
  }


  ############ Phase 3 – Observability ############

  ################################
  # Install Node Exporter (host binary)
  ################################
  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "scripts/install_node_exporter.sh"
  }

  ################################
  # Create Prometheus directories (root-owned)
  ################################
  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "scripts/install_prometheus_dirs.sh"
  }

  ################################
  # Create Grafana directories
  ################################
  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "scripts/install_grafana_dirs.sh"
  }

  provisioner "file" {
    source      = "files/grafana"
    destination = "/tmp/grafana"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/grafana/provisioning",
      "sudo mkdir -p /opt/grafana/dashboards",

      "sudo cp -r /tmp/grafana/provisioning/* /etc/grafana/provisioning/",
      "sudo cp -r /tmp/grafana/dashboards/* /opt/grafana/dashboards/",

      "sudo chown -R 472:472 /opt/grafana"
    ]
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

  provisioner "file" {
    source      = "systemd/grafana.service"
    destination = "/tmp/grafana.service"
  }

  provisioner "file" {
    source      = "systemd/platform-api.service"
    destination = "/tmp/platform-api.service"
  }
  ###############################
  ## Update Platform API service
  ###############################

  provisioner "file" {
    source      = "systemd/platform-update.service"
    destination = "/tmp/platform-update.service"
  }

  provisioner "file" {
    source      = "systemd/platform-update.timer"
    destination = "/tmp/platform-update.timer"
  }

  provisioner "file" {
    source      = "scripts/platform-update.sh"
    destination = "/tmp/platform-update.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/platform-update.sh /usr/local/bin/platform-update.sh",
      "sudo chmod +x /usr/local/bin/platform-update.sh",

      "sudo mv /tmp/platform-update.service /etc/systemd/system/",
      "sudo mv /tmp/platform-update.timer /etc/systemd/system/",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now platform-update.timer"
    ]
  }


  ################################
  # Move systemd units into place
  ## Will move to sudo cp /tmp/systemd/*.service /etc/systemd/system/  but for now display what's happening! 
  ################################

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/platform",
      "sudo bash -c 'cat > /etc/platform/api.env <<EOF\nIMAGE_URI=046685909731.dkr.ecr.us-east-1.amazonaws.com/api:latest\nPORT=3000\nNODE_ENV=production\nEOF'",

      "sudo mv /tmp/node_exporter.service /etc/systemd/system/node_exporter.service",
      "sudo mv /tmp/prometheus.service /etc/systemd/system/prometheus.service",
      "sudo mv /tmp/grafana.service /etc/systemd/system/grafana.service",
      "sudo mv /tmp/systemd/pushgateway.service /etc/systemd/system/pushgateway.service",
      "sudo mv /tmp/platform-api.service /etc/systemd/system/platform-api.service",

      "sudo systemctl daemon-reload",

      "sudo systemctl enable node_exporter.service",
      "sudo systemctl enable prometheus.service",
      "sudo systemctl enable grafana.service",
      "sudo systemctl enable pushgateway.service",
      "sudo systemctl enable platform-api.service"
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


#####################
# HUGO 
#####################

# Ensure directories exist
provisioner "shell" {
  inline = [
    "sudo mkdir -p /opt/hugo/site",
    "sudo mkdir -p /opt/platform/scripts",
    "sudo chown -R ubuntu:ubuntu /opt/hugo"
  ]
}

# Upload Hugo site FIRST
provisioner "file" {
  source      = "${path.root}/../../../apps/hugo/site"
  destination = "/tmp/hugo-site"
}

# THEN move it
provisioner "shell" {
  inline = [
    "sudo rsync -av --delete /tmp/hugo-site/ /opt/hugo/site/",
    "sudo rm -rf /tmp/hugo-site"
  ]
}


# Move EVERYTHING in one step (idempotent-safe)
provisioner "shell" {
  inline = [
    # Move script safely
    "if [ -f /tmp/build-hugo.sh ]; then sudo mv /tmp/build-hugo.sh /opt/platform/scripts/build-hugo.sh; fi",
    "sudo chmod +x /opt/platform/scripts/build-hugo.sh || true",

    # Move site
    "sudo rsync -av --delete /tmp/hugo-site/ /opt/hugo/site/",
    "sudo rm -rf /tmp/hugo-site",

    # Debug visibility
    "echo '=== HUGO SCRIPT ==='",
    "ls -la /opt/platform/scripts",
    "echo '=== HUGO SITE ==='",
    "ls -la /opt/hugo/site"
  ]
}


provisioner "file" {
  source      = "${path.root}/../../../apps/hugo/site"
  destination = "/tmp/hugo-site"
}


sudo test -f /opt/platform/scripts/build-hugo.sh || (echo "MISSING HUGO SCRIPT" && exit 1)


sudo systemctl daemon-reload
sudo systemctl enable hugo


######################
# Hugo Sync
######################
provisioner "file" {
  source      = "systemd/hugo-sync.timer"
  destination = "/tmp/hugo-sync.timer"
}

provisioner "file" {
  source      = "systemd/hugo-sync.service"
  destination = "/tmp/hugo-sync.service"
}


provisioner "shell" {
  inline = [
    "sudo mv /tmp/hugo-sync.service /etc/systemd/system/",
    "sudo mv /tmp/hugo-sync.timer /etc/systemd/system/",

    "sudo systemctl daemon-reload",
    "sudo systemctl enable --now hugo-sync.timer"
  ]
}



##################
# Plaform Rehydrate
####################### 
provisioner "file" {
  source      = "scripts/platform-rehydrate.sh"
  destination = "/tmp/platform-rehydrate.sh"
}

provisioner "file" {
  source      = "systemd/platform-rehydrate.service"
  destination = "/tmp/platform-rehydrate.service"
}

provisioner "shell" {
  inline = [
    "sudo mv /tmp/platform-rehydrate.sh /usr/local/bin/platform-rehydrate.sh",
    "sudo chmod +x /usr/local/bin/platform-rehydrate.sh",

    "sudo mv /tmp/platform-rehydrate.service /etc/systemd/system/",

    "sudo systemctl daemon-reload",
    "sudo systemctl enable platform-rehydrate.service"
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
