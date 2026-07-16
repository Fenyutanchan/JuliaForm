#!/usr/bin/env bash

set -Eeuo pipefail

readonly runtime_image_alias="juliaform-wolfram-runtime:ci"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"

fail() {
  echo "wolfram-runtime: $*" >&2
  exit 1
}

run_in_runtime() {
  (( $# > 0 )) || fail "run requires a command"
  docker run --rm \
    --user root \
    --workdir /workspace \
    --volume "${repository_root}:/workspace" \
    "${runtime_image_alias}" "$@"
}

case "${1:-}" in
  prepare)
    shift
    (( $# == 0 )) || fail "prepare does not accept arguments"
    : "${WOLFRAM_RUNTIME_IMAGE:?WOLFRAM_RUNTIME_IMAGE is unavailable}"

    docker pull --quiet "${WOLFRAM_RUNTIME_IMAGE}" >/dev/null
    docker tag "${WOLFRAM_RUNTIME_IMAGE}" "${runtime_image_alias}"
    run_in_runtime wolframscript -code \
      'If[StringStartsQ[$Version, "15.0.0 "], Print[$Version], Print["Expected Wolfram 15.0.0, got ", $Version]; Exit[1]]'
    ;;
  run)
    shift
    run_in_runtime "$@"
    ;;
  *)
    fail "usage: ${0##*/} {prepare|run}"
    ;;
esac
