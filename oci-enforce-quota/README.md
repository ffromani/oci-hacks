# OCI-enforce-quota

A OCI hook to revert the behavior of kubernetes issue 70585
* triggers only for pods which have the annotation `openshift-kni.io/enforce-cpu-quota: "true"`
* the hook only changes the **container** cgroup settings, not the sandbox (pod) settings
* a example `MachineConfig` is provided to deploy the hook on cluster
* use `generate.sh` to get a fresh `MachineConfig` once you modified either the hook or its config.

AI disclosure:
The hook was implemented with contributions from gemini 2.5 pro

AI-Attribution: AIA PAI CeNc Hin R gemini-2.5-pro v1.0
