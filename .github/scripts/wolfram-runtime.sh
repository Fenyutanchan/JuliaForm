#!/usr/bin/env bash

set -Eeuo pipefail

readonly container_name="${WOLFRAM_CONTAINER_NAME:-juliaform-wolfram-runtime}"
readonly runner_temporary_directory="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
readonly runtime_state_directory="${JULIAFORM_RUNTIME_STATE:-${runner_temporary_directory}/juliaform-wolfram-runtime}"
readonly image_id_path="${runtime_state_directory}/image-id"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"

fail() {
  echo "wolfram-runtime: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

require_no_arguments() {
  (( $# == 0 )) || fail "unexpected arguments: $*"
}

prepare_runtime() {
  local runtime_image_id=""
  local runtime_image="${WOLFRAM_RUNTIME_IMAGE:-}"

  require_no_arguments "$@"
  [[ -n "${runtime_image}" ]] ||
    fail "WOLFRAM_RUNTIME_IMAGE is empty"

  mkdir -p -- "${runtime_state_directory}"
  chmod 700 "${runtime_state_directory}"

  docker pull --quiet "${runtime_image}" >/dev/null
  runtime_image_id="$(docker image inspect --format '{{.Id}}' "${runtime_image}")"
  [[ "${runtime_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] ||
    fail "pulled image has an invalid local image ID"
  printf '%s\n' "${runtime_image_id}" > "${image_id_path}"
  chmod 600 "${image_id_path}"

  run_in_runtime wolframscript -code \
    'If[StringStartsQ[$Version, "15.0.0 "], Print[$Version], Print["Expected Wolfram 15.0.0, got ", $Version]; Exit[1]]'
}

run_in_runtime() {
  local runtime_image_id=""

  (( $# > 0 )) || fail "run requires a command"
  [[ -f "${image_id_path}" ]] ||
    fail "runtime is not prepared: missing local image ID"
  IFS= read -r runtime_image_id < "${image_id_path}"
  [[ "${runtime_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] ||
    fail "runtime state contains an invalid local image ID"

  docker run --rm \
    --name "${container_name}" \
    --user root \
    --workdir /workspace \
    --volume "${repository_root}:/workspace" \
    "${runtime_image_id}" "$@"
}

cleanup_runtime() {
  require_no_arguments "$@"

  docker container rm --force "${container_name}" >/dev/null 2>&1 || true
  rm -f -- "${image_id_path}"
}

require_command docker

case "${1:-}" in
  prepare)
    shift
    prepare_runtime "$@"
    ;;
  run)
    shift
    run_in_runtime "$@"
    ;;
  cleanup)
    shift
    cleanup_runtime "$@"
    ;;
  *)
    fail "usage: ${0##*/} {prepare|run|cleanup}"
    ;;
esac
