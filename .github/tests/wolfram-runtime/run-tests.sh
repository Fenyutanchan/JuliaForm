#!/usr/bin/env bash

set -Eeuo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../../.." && pwd)"
runtime_helper="${repository_root}/.github/scripts/wolfram-runtime.sh"
temporary_directory="$(mktemp -d)"
mock_bin="${temporary_directory}/bin"
mock_log="${temporary_directory}/docker.log"
mock_state="${temporary_directory}/container-running"

fail() {
  echo "wolfram-runtime tests: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local path="$2"

  grep -F -- "${expected}" "${path}" >/dev/null ||
    fail "expected ${path} to contain: ${expected}"
}

assert_not_contains() {
  local rejected="$1"
  local path="$2"

  if grep -F -- "${rejected}" "${path}" >/dev/null; then
    fail "expected ${path} not to contain: ${rejected}"
  fi
}

cleanup() {
  rm -rf -- "${temporary_directory}"
}

trap cleanup EXIT
mkdir -p -- "${mock_bin}"

cat > "${mock_bin}/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash

set -Eeuo pipefail

log_command() {
  local argument=""

  printf '%s' "$1" >> "${MOCK_DOCKER_LOG}"
  shift
  for argument in "$@"; do
    printf ' <%s>' "${argument}" >> "${MOCK_DOCKER_LOG}"
  done
  printf '\n' >> "${MOCK_DOCKER_LOG}"
}

case "${1:-}" in
  container)
    operation="${2:-}"
    shift 2
    case "${operation}" in
      inspect)
        [[ -f "${MOCK_DOCKER_STATE}" ]]
        ;;
      rm)
        log_command "container rm" "$@"
        rm -f -- "${MOCK_DOCKER_STATE}"
        ;;
      *)
        echo "unexpected docker container operation: ${operation}" >&2
        exit 1
        ;;
    esac
    ;;
  login)
    token="$(cat)"
    [[ "${token}" == "${MOCK_EXPECTED_TOKEN}" ]]
    shift
    log_command "login" "$@"
    ;;
  pull)
    shift
    log_command "pull" "$@"
    ;;
  run)
    shift
    log_command "run" "$@"
    touch "${MOCK_DOCKER_STATE}"
    printf 'mock-container-id\n'
    ;;
  exec)
    shift
    log_command "exec" "$@"
    if [[ "${MOCK_FAIL_VERSION_CHECK:-false}" == "true" ]] &&
       [[ " $* " == *" -code "* ]]; then
      printf 'Expected Wolfram 15.0.0, got 14.0.0\n' >&2
      exit 1
    fi
    if [[ " $* " == *" -code "* ]]; then
      printf '15.0.0 for Linux x86 (64-bit)\n'
    fi
    ;;
  logout)
    shift
    log_command "logout" "$@"
    ;;
  *)
    echo "unexpected docker command: ${1:-<empty>}" >&2
    exit 1
    ;;
esac
MOCK_DOCKER
chmod +x "${mock_bin}/docker"

export PATH="${mock_bin}:${PATH}"
export MOCK_DOCKER_LOG="${mock_log}"
export MOCK_DOCKER_STATE="${mock_state}"
export MOCK_EXPECTED_TOKEN="test-token"
export RUNNER_TEMP="${temporary_directory}/runner-temp"
export DOCKERHUB_USERNAME="test-user"
export DOCKERHUB_TOKEN="test-token"
export WOLFRAM_RUNTIME_IMAGE="private/example@sha256:0123456789abcdef"

start_output="${temporary_directory}/start.out"
bash "${runtime_helper}" start > "${start_output}"
[[ -f "${mock_state}" ]] || fail "start did not create the mock container"
assert_contains "15.0.0 for Linux x86 (64-bit)" "${start_output}"
assert_contains "login <--username> <test-user> <--password-stdin>" "${mock_log}"
assert_contains "pull <--quiet> <private/example@sha256:0123456789abcdef>" "${mock_log}"
assert_contains "run <--detach> <--name> <juliaform-wolfram-runtime>" "${mock_log}"
assert_contains "<--user> <root> <--workdir> </workspace>" "${mock_log}"
assert_contains "<--entrypoint> <tail> <private/example@sha256:0123456789abcdef> <-f> </dev/null>" "${mock_log}"
assert_contains "exec <juliaform-wolfram-runtime> <wolframscript> <-code>" "${mock_log}"
assert_not_contains "test-token" "${mock_log}"
assert_not_contains "test-token" "${start_output}"

bash "${runtime_helper}" exec wolframscript -file Tests/RunTests.wls
assert_contains "exec <juliaform-wolfram-runtime> <wolframscript> <-file> <Tests/RunTests.wls>" "${mock_log}"

bash "${runtime_helper}" stop
[[ ! -e "${mock_state}" ]] || fail "stop did not remove the mock container"
assert_contains "container rm <--force> <juliaform-wolfram-runtime>" "${mock_log}"
assert_contains "logout" "${mock_log}"

missing_secret_error="${temporary_directory}/missing-secret.err"
if env -u WOLFRAM_RUNTIME_IMAGE \
  bash "${runtime_helper}" start 2> "${missing_secret_error}"; then
  fail "start unexpectedly accepted a missing image secret"
fi
assert_contains "WOLFRAM_RUNTIME_IMAGE is empty" "${missing_secret_error}"

export MOCK_FAIL_VERSION_CHECK="true"
version_error="${temporary_directory}/version.err"
if bash "${runtime_helper}" start >/dev/null 2> "${version_error}"; then
  fail "start unexpectedly accepted the wrong Wolfram version"
fi
assert_contains "Expected Wolfram 15.0.0, got 14.0.0" "${version_error}"
bash "${runtime_helper}" stop

echo "wolfram-runtime mock tests passed"
