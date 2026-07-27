#!/usr/bin/env bash
# platform-validation.sh (fd-health-check)
#
# Reports per-container file-descriptor usage against each container's
# configured limit, plus host-level file-max. Use --verbose to also
# print Docker/containerd/OS version info (off by default — that output
# fingerprints the host and shouldn't go into shared tickets/logs
# unless you actually need it there).
#
# Usage:
#   ./platform-validation.sh              # FD table only
#   ./platform-validation.sh --verbose    # FD table + host/version info

set -uo pipefail  # not -e: a single missing/gone container shouldn't abort the whole report

VERBOSE=0
if [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]]; then
    VERBOSE=1
fi

echo "======================================="
echo "Docker File Descriptor Health Check"
echo "Host: $(hostname)"
echo "Time: $(date)"
echo "======================================="

if ! command -v docker >/dev/null 2>&1; then
    echo "docker command not found — nothing to check." >&2
    exit 1
fi

printf "\n%-35s %-8s %-8s %-8s\n" "Container" "PID" "FDs" "Limit"

TOTAL=0

while IFS= read -r c; do
    [[ -z "$c" ]] && continue

    PID=$(docker inspect --format '{{.State.Pid}}' "$c" 2>/dev/null)
    [[ -z "$PID" || "$PID" == "0" ]] && continue

    # Container can exit between the docker inspect above and the /proc
    # read below — skip cleanly instead of erroring on a vanished PID.
    if [[ ! -d "/proc/$PID" ]]; then
        printf "%-35s %-8s %-8s %-8s\n" "$c" "$PID" "gone" "-"
        continue
    fi

    FD_COUNT=$(ls "/proc/$PID/fd" 2>/dev/null | wc -l)
    FD_LIMIT=$(awk '/Max open files/ {print $4}' "/proc/$PID/limits" 2>/dev/null)
    FD_LIMIT="${FD_LIMIT:-unknown}"

    TOTAL=$((TOTAL + FD_COUNT))

    printf "%-35s %-8s %-8s %-8s\n" "$c" "$PID" "$FD_COUNT" "$FD_LIMIT"
done < <(docker ps --format '{{.Names}}')

echo
echo "---------------------------------------"
echo "Total Stack FDs : $TOTAL"

echo
echo "Host file-max:"
cat /proc/sys/fs/file-nr

if [[ "$VERBOSE" -eq 1 ]]; then
    echo
    echo "Docker daemon ulimits:"
    if [[ -f /etc/docker/daemon.json ]]; then
        cat /etc/docker/daemon.json
    else
        echo "(no /etc/docker/daemon.json present)"
    fi

    echo
    command -v docker >/dev/null 2>&1 && docker version --format 'Docker {{.Server.Version}}' 2>/dev/null
    command -v containerd >/dev/null 2>&1 && containerd --version
    command -v lsb_release >/dev/null 2>&1 && lsb_release -a 2>/dev/null
    command -v hostnamectl >/dev/null 2>&1 && hostnamectl
    uname -r
fi
