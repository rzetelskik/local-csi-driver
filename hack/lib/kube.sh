#!/bin/bash
#
# Copyright (C) 2024 ScyllaDB
#

set -euExo pipefail
shopt -s inherit_errexit

FIELD_MANAGER="${FIELD_MANAGER:-so-default}"

function kubectl_apply {
  kubectl apply --server-side=true --field-manager="${FIELD_MANAGER}" --force-conflicts "$@"
}

function kubectl_create {
    if [[ -z "${REENTRANT+x}" ]]; then
        # In an actual CI run we have to enforce that no two objects have the same name.
        kubectl create --field-manager="${FIELD_MANAGER}" "$@"
    else
        # For development iterations we want to update the objects.
        kubectl_apply "$@"
    fi
}

function wait-for-object-creation {
    for i in {1..30}; do
        { kubectl -n "${1}" get "${2}" && break; } || sleep 1
    done
}

# $1 - namespace
# $2 - pod name
# $3 - container name
function wait-for-container-exit-with-logs {
  exit_code=""
  while [[ "${exit_code}" == "" ]]; do
    kubectl -n="${1}" logs -f pod/"${2}" -c="${3}" > /dev/stderr || echo "kubectl logs failed before pod has finished, retrying..." > /dev/stderr
    exit_code="$( kubectl -n="${1}" get pods/"${2}" --template='{{ range .status.containerStatuses }}{{ if and (eq .name "'"${3}"'") (ne .state.terminated.exitCode nil) }}{{ .state.terminated.exitCode }}{{ end }}{{ end }}' )"
  done
  echo -n "${exit_code}"
}
