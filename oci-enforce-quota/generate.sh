#!/bin/sh
export CONF_CONTENT=$( base64 -w 0 99-enforce-quota.json )
export HOOK_CONTENT=$( base64 -w 0 oci-enforce-quota-hook.sh )
envsubst < mc-oci-enforce-quota-hook.yaml.tmpl 
