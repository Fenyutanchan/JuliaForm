#!/usr/bin/env bash

set -Eeuo pipefail

readonly ACTIONLINT_VERSION="1.7.12"
readonly ACTIONLINT_ARCHIVE="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
# From the checksum file attached to the official v1.7.12 release:
# https://github.com/rhysd/actionlint/releases/tag/v1.7.12
readonly ACTIONLINT_SHA256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
readonly ACTIONLINT_URL="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${ACTIONLINT_ARCHIVE}"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"
temporary_directory=""
actionlint_binary="${ACTIONLINT_BIN:-}"
actionlint_version=""

fail() {
  echo "repository-config: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

cleanup() {
  if [[ -n "${temporary_directory}" && -d "${temporary_directory}" ]]; then
    rm -rf -- "${temporary_directory}"
  fi
}

trap cleanup EXIT

install_actionlint() {
  local actual_sha256=""

  [[ "$(uname -s)" == "Linux" ]] ||
    fail "automatic actionlint installation supports Linux only; set ACTIONLINT_BIN on this platform"
  case "$(uname -m)" in
    x86_64|amd64) ;;
    *) fail "automatic actionlint installation requires Linux amd64; set ACTIONLINT_BIN on this platform" ;;
  esac

  require_command curl
  require_command tar
  require_command sha256sum

  temporary_directory="$(mktemp -d)"
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    --output "${temporary_directory}/${ACTIONLINT_ARCHIVE}" \
    "${ACTIONLINT_URL}"
  actual_sha256="$(sha256sum -- "${temporary_directory}/${ACTIONLINT_ARCHIVE}")"
  actual_sha256="${actual_sha256%% *}"
  [[ "${actual_sha256}" == "${ACTIONLINT_SHA256}" ]] ||
    fail "actionlint archive SHA-256 mismatch: got ${actual_sha256}"

  tar -xzf "${temporary_directory}/${ACTIONLINT_ARCHIVE}" \
    -C "${temporary_directory}" actionlint
  actionlint_binary="${temporary_directory}/actionlint"
}

require_command bash
require_command find
require_command mktemp
require_command ruby

if [[ -z "${actionlint_binary}" ]]; then
  install_actionlint
fi
[[ -x "${actionlint_binary}" ]] || fail "ACTIONLINT_BIN is not executable: ${actionlint_binary}"
actionlint_version="$("${actionlint_binary}" -version)"
actionlint_version="${actionlint_version%%$'\n'*}"
[[ "${actionlint_version}" == "${ACTIONLINT_VERSION}" ]] ||
  fail "actionlint must be exactly ${ACTIONLINT_VERSION}"

cd -- "${repository_root}"
shopt -s nullglob
workflow_files=(.github/workflows/*.yml .github/workflows/*.yaml)
(( ${#workflow_files[@]} > 0 )) || fail "no workflow files found"
"${actionlint_binary}" "${workflow_files[@]}"

while IFS= read -r -d '' shell_file; do
  bash -n "${shell_file}"
done < <(find .github -type f \( -name '*.sh' -o -name 'gh' \) -print0)

ruby .github/scripts/validate-repository-config.rb
bash .github/tests/publish-paclet/run-tests.sh

echo "Repository configuration checks passed."
