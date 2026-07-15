#!/usr/bin/env bash

set -Eeuo pipefail

readonly container_name="${WOLFRAM_CONTAINER_NAME:-juliaform-wolfram-runtime}"
readonly docker_config="${JULIAFORM_DOCKER_CONFIG:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/juliaform-docker-auth}"

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

start_runtime() {
  local runtime_image="${WOLFRAM_RUNTIME_IMAGE:-}"

  require_no_arguments "$@"
  [[ -n "${runtime_image}" ]] ||
    fail "WOLFRAM_RUNTIME_IMAGE is empty"
  [[ -n "${DOCKERHUB_USERNAME:-}" ]] ||
    fail "DOCKERHUB_USERNAME is empty"
  [[ -n "${DOCKERHUB_TOKEN:-}" ]] ||
    fail "DOCKERHUB_TOKEN is empty"

  if docker container inspect "${container_name}" >/dev/null 2>&1; then
    fail "container already exists: ${container_name}"
  fi

  mkdir -p -- "${docker_config}"
  chmod 700 "${docker_config}"
  export DOCKER_CONFIG="${docker_config}"

  printf '%s' "${DOCKERHUB_TOKEN}" |
    docker login --username "${DOCKERHUB_USERNAME}" --password-stdin >/dev/null
  docker pull --quiet "${runtime_image}" >/dev/null
  docker run --detach \
    --name "${container_name}" \
    --user root \
    --workdir /workspace \
    --volume "${repository_root}:/workspace" \
    --entrypoint tail \
    "${runtime_image}" -f /dev/null >/dev/null

  docker exec "${container_name}" wolframscript -code \
    'If[StringStartsQ[$Version, "15.0.0 "], Print[$Version], Print["Expected Wolfram 15.0.0, got ", $Version]; Exit[1]]'
}

run_in_runtime() {
  (( $# > 0 )) || fail "exec requires a command"
  docker container inspect "${container_name}" >/dev/null 2>&1 ||
    fail "container is not running: ${container_name}"
  docker exec "${container_name}" "$@"
}

stop_runtime() {
  require_no_arguments "$@"
  export DOCKER_CONFIG="${docker_config}"

  docker container rm --force "${container_name}" >/dev/null 2>&1 || true
  docker logout >/dev/null 2>&1 || true
}

require_command docker

case "${1:-}" in
  start)
    shift
    start_runtime "$@"
    ;;
  exec)
    shift
    run_in_runtime "$@"
    ;;
  stop)
    shift
    stop_runtime "$@"
    ;;
  *)
    fail "usage: ${0##*/} {start|exec|stop}"
    ;;
esac
