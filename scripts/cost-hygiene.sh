#!/bin/bash
# cost-hygiene.sh - AWS cost checks for Platform Foundation
#
# Usage:
#   ./scripts/cost-hygiene.sh credits [days]   t3 surplus-credit charges (default 14 days)
#   ./scripts/cost-hygiene.sh audit            dry run: which AMIs/snapshots are removable
#   ./scripts/cost-hygiene.sh cleanup          same selection, then confirm and delete
#
# Env overrides: INSTANCE_NAME (ops-01), SSM_AMI_PARAM (/devopslab/ami/ops/latest),
#                KEEP_NEWEST (2)
#
# An AMI is KEPT if it is the SSM "latest" AMI, is used by any instance
# (running or stopped), or is within the newest KEEP_NEWEST by creation date.
# Everything else is a REMOVE candidate. Snapshots that no AMI references are
# listed for manual review and are never deleted automatically.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

./scripts/ensure-sso.sh

INSTANCE_NAME="${INSTANCE_NAME:-ops-01}"
SSM_AMI_PARAM="${SSM_AMI_PARAM:-/devopslab/ami/ops/latest}"
KEEP_NEWEST="${KEEP_NEWEST:-2}"
CREDIT_PRICE="0.05"   # USD per vCPU-hour; 60 credits = 1 vCPU-hour
SNAP_PRICE="0.05"     # USD per GiB-month (upper bound; billed on used blocks)

CAND_AMIS=()
CAND_SNAPS=()

credits() {
  local days="${1:-14}" ids id
  ids=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
  if [[ -z "$ids" ]]; then
    echo "No instance tagged Name=${INSTANCE_NAME}"
    exit 1
  fi
  for id in $ids; do
    echo "== ${id}: surplus credits charged, last ${days} days (bucket start date) =="
    aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
      --metric-name CPUSurplusCreditsCharged \
      --dimensions "Name=InstanceId,Value=${id}" \
      --start-time "$(date -u -d "${days} days ago" +%FT%TZ)" \
      --end-time "$(date -u +%FT%TZ)" \
      --period 86400 --statistics Sum \
      --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,Sum]' --output text |
    awk -v price="$CREDIT_PRICE" '
      { printf "%s  %10.1f\n", substr($1, 1, 10), $2; t += $2 }
      END { printf "TOTAL credits: %.1f  (~$%.2f)\n", t, t / 60 * price }'
  done
}

audit() {
  local current in_use all_amis ami i name created snaps reason referenced gib
  local -a snap_arr
  CAND_AMIS=()
  CAND_SNAPS=()

  current=$(aws ssm get-parameter --name "$SSM_AMI_PARAM" \
    --query Parameter.Value --output text)
  in_use=" $(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].ImageId' --output text | tr '\t' ' ') "

  echo "SSM latest AMI: $current"
  echo "KEEP_NEWEST:    $KEEP_NEWEST"
  echo

  all_amis=$(aws ec2 describe-images --owners self \
    --query 'reverse(sort_by(Images,&CreationDate))[].ImageId' --output text)

  i=0
  for ami in $all_amis; do
    i=$((i + 1))
    IFS=$'\t' read -r name created snaps < <(aws ec2 describe-images \
      --image-ids "$ami" \
      --query 'Images[0].[Name,CreationDate,join(`","`,BlockDeviceMappings[].Ebs.SnapshotId)]' \
      --output text)

    reason=""
    if [[ "$ami" == "$current" ]]; then
      reason="SSM latest"
    elif [[ "$in_use" == *" $ami "* ]]; then
      reason="used by an instance"
    elif (( i <= KEEP_NEWEST )); then
      reason="within newest ${KEEP_NEWEST}"
    fi

    if [[ -n "$reason" ]]; then
      printf 'KEEP    %-22s %-34s %s  (%s)\n' "$ami" "$name" "${created:0:10}" "$reason"
    else
      printf 'REMOVE  %-22s %-34s %s  snaps: %s\n' "$ami" "$name" "${created:0:10}" "$snaps"
      CAND_AMIS+=("$ami")
      IFS=',' read -ra snap_arr <<< "$snaps"
      CAND_SNAPS+=("${snap_arr[@]}")
    fi
  done

  echo
  echo "Snapshots not referenced by any AMI (manual review only, never auto-deleted):"
  referenced=" $(aws ec2 describe-images --owners self \
    --query 'Images[].BlockDeviceMappings[].Ebs.SnapshotId' --output text | tr '\t' ' ') "
  aws ec2 describe-snapshots --owner-ids self \
    --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]' --output text |
  while IFS=$'\t' read -r sid size started desc; do
    if [[ "$referenced" != *" $sid "* ]]; then
      printf '  %s  %sGiB  %s  %s\n' "$sid" "$size" "${started:0:10}" "$desc"
    fi
  done

  if (( ${#CAND_SNAPS[@]} > 0 )); then
    gib=$(aws ec2 describe-snapshots --snapshot-ids "${CAND_SNAPS[@]}" \
      --query 'sum(Snapshots[].VolumeSize)' --output text)
    echo
    awk -v n="${#CAND_AMIS[@]}" -v s="${#CAND_SNAPS[@]}" -v g="$gib" -v p="$SNAP_PRICE" \
      'BEGIN { printf "Removal set: %d AMI(s), %d snapshot(s), %s GiB -> at most ~$%.2f/month\n", n, s, g, g * p }'
  fi
}

cleanup() {
  local ans ami s
  audit
  if (( ${#CAND_AMIS[@]} == 0 )); then
    echo
    echo "Nothing to remove."
    return 0
  fi
  echo
  read -rp "Type 'yes' to deregister the REMOVE AMIs and delete their snapshots: " ans
  if [[ "$ans" != "yes" ]]; then
    echo "Cancelled."
    return 0
  fi
  for ami in "${CAND_AMIS[@]}"; do
    aws ec2 deregister-image --image-id "$ami" && echo "deregistered $ami" || echo "skip: $ami"
  done
  for s in "${CAND_SNAPS[@]}"; do
    aws ec2 delete-snapshot --snapshot-id "$s" && echo "deleted $s" || echo "skip: $s"
  done
  echo "Done."
}

case "${1:-}" in
  credits) credits "${2:-14}" ;;
  audit)   audit ;;
  cleanup) cleanup ;;
  *)       sed -n '2,9p' "$0"; exit 1 ;;
esac
