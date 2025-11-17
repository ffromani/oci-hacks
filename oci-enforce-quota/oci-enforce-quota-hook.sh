#!/bin/bash
#
# OCI prestart hook to enforce a 100% CPU quota on cgroup v2 systems.
# This script is intended as a workaround for applications with exclusive CPUs
# that cannot parse an unlimited ('max') CPU quota.
#
# It activates ONLY if a container has the following annotation:
#   openshift-kni.io/enforce-cpu-quota: "true"
#
# AI-Attribution: AIA PAI CeNc Hin R gemini-2.5-pro v1.0

set -o pipefail

log_info() {
    echo "[INFO] $1" | systemd-cat -t oci-enforce-quota-hook -p info
}

log_error() {
    echo "[ERROR] $1" | systemd-cat -t oci-enforce-quota-hook -p err
}

# https://kubernetes.io/docs/concepts/architecture/cgroups/
cgroupfs=$( stat -fc %T /sys/fs/cgroup/ )
if [  "$cgroupfs" -ne "cgroup2fs" ]; then
    # Exit silently to avoid log spam on cgroup v1 systems.
    exit 0
fi

if ! command -v jq &> /dev/null; then
    log_error "missing jq" # this should never happen.
    exit 0
fi

container_state=$(cat)
if [ -z "$container_state" ]; then
    log_error "no container state from stdin." # this should never happen
    exit 0
fi

container_id_short=$(echo "$container_state" | jq -r '.id | .[0:12]') # Short ID for cleaner logs

log_info "Container ${container_id_short}: Activation annotation found. Evaluating CPU quota."

pid=$(echo "$container_state" | jq -r '.pid')
if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
    log_error "Container ${container_id_short}: Invalid PID ${pid} from container state."
    exit 0
fi

# The v2 format in /proc/<pid>/cgroup is a single line: '0::/path/to/cgroup'.
cgroup_path=$(grep '^0::' "/proc/$pid/cgroup" | cut -d: -f3)
if [ -z "$cgroup_path" ]; then
    log_error "Container ${container_id_short}: Could not determine cgroup v2 path from /proc/${pid}/cgroup."
    exit 0
fi

full_cgroup_path="/sys/fs/cgroup${cgroup_path}"
cpu_max_file="${full_cgroup_path}/cpu.max"

if [ ! -f "$cpu_max_file" ]; then
    log_info "Container ${container_id_short}: cpu.max file not found at ${cpu_max_file}."
    exit 0
fi

current_cpu_max=$(cat "$cpu_max_file")
quota=$(echo "$current_cpu_max" | cut -d' ' -f1)
period=$(echo "$current_cpu_max" | cut -d' ' -f2)

# Only act if the quota is currently unlimited ('max').
if [ "$quota" -ne "max" ]; then
    log_info "Container ${container_id_short}: CPU quota is already set to '${quota}'."
    exit 0
fi

new_quota="${period} ${period}"
log_info "Container ${container_id_short}: Unlimited CPU quota detected. Setting '${new_quota}' to ${cpu_max_file}."
    
# Write the new value. Use a subshell to prevent any potential script variable contamination.
(echo "$new_quota" > "$cpu_max_file")
if [ $? -ne 0 ]; then
    log_error "Container ${container_id_short}: Failed to write to ${cpu_max_file}. Check file permissions."
fi

# Read back to be sure
sys_quota=$(cat ${cpu_max_file})
log_info "Container ${container_id_short}: CPU quota feedback: desired ${new_quota} detected ${sys_quota}."

exit 0
