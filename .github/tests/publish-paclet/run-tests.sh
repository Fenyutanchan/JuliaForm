#!/usr/bin/env bash

set -Eeuo pipefail

test_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${test_directory}/../../.." && pwd)"
script="${repository_root}/.github/scripts/publish-paclet.sh"
mock_root="$(mktemp -d)"
export PATH="${test_directory}:${PATH}"
export GH_TOKEN=test-token
export GH_REPO=example/JuliaForm

cleanup() {
  rm -rf -- "${mock_root}"
}

trap cleanup EXIT

new_state() {
  local name="$1"
  export MOCK_STATE="${mock_root}/${name}"
  mkdir -p "${MOCK_STATE}/dist" "${MOCK_STATE}/asset-files"
  : > "${MOCK_STATE}/calls.log"
  : > "${MOCK_STATE}/assets"
  unset MOCK_FAIL_ASSET_LIST MOCK_FAIL_FINAL_EDIT MOCK_FAIL_PATCH
}

expect_failure() {
  if "$@" >"${MOCK_STATE}/stdout" 2>"${MOCK_STATE}/stderr"; then
    echo "expected command to fail: $*" >&2
    exit 1
  fi
}

new_state stable-create
touch "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
export GITHUB_SHA=1111111111111111111111111111111111111111
bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
[[ "$(cat "${MOCK_STATE}/draft")" == "false" ]]
grep -Fxq 'JuliaForm-1.2.3.paclet' "${MOCK_STATE}/assets"
grep -Fq 'release create v1.2.3' "${MOCK_STATE}/calls.log"
grep -Fq 'release download v1.2.3' "${MOCK_STATE}/calls.log"

new_state stable-draft-match
printf 'matching archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
touch "${MOCK_STATE}/release"
printf 'true\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-1.2.3.paclet\n' > "${MOCK_STATE}/assets"
cp -- "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet" \
  "${MOCK_STATE}/asset-files/JuliaForm-1.2.3.paclet"
bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
[[ "$(cat "${MOCK_STATE}/draft")" == "false" ]]
grep -Fq 'release download v1.2.3' "${MOCK_STATE}/calls.log"
! grep -Fq 'release upload v1.2.3' "${MOCK_STATE}/calls.log"

new_state stable-draft-mismatch
printf 'current archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
touch "${MOCK_STATE}/release"
printf 'true\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-1.2.3.paclet\n' > "${MOCK_STATE}/assets"
printf 'stale archive\n' > "${MOCK_STATE}/asset-files/JuliaForm-1.2.3.paclet"
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
grep -Fq 'has SHA-256' "${MOCK_STATE}/stderr"
[[ "$(cat "${MOCK_STATE}/draft")" == "true" ]]
! grep -Fq -- '--draft=false' "${MOCK_STATE}/calls.log"

new_state stable-draft-extra-asset
printf 'current archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
touch "${MOCK_STATE}/release"
printf 'true\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-1.2.3.paclet\nnotes.txt\n' > "${MOCK_STATE}/assets"
cp -- "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet" \
  "${MOCK_STATE}/asset-files/JuliaForm-1.2.3.paclet"
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
grep -Fq 'contains unexpected asset: notes.txt' "${MOCK_STATE}/stderr"
[[ "$(cat "${MOCK_STATE}/draft")" == "true" ]]
! grep -Fq -- '--draft=false' "${MOCK_STATE}/calls.log"

new_state stable-leading-zero
touch "${MOCK_STATE}/dist/JuliaForm-01.2.3.paclet"
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v01.2.3
grep -Fq 'canonical vMAJOR.MINOR.PATCH' "${MOCK_STATE}/stderr"
[[ ! -s "${MOCK_STATE}/calls.log" ]]

new_state stable-final-response-recovery
printf 'published archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
export MOCK_FAIL_FINAL_EDIT=1
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
[[ "$(cat "${MOCK_STATE}/draft")" == "false" ]]
unset MOCK_FAIL_FINAL_EDIT
: > "${MOCK_STATE}/calls.log"
bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
grep -Fq 'release download v1.2.3' "${MOCK_STATE}/calls.log"
! grep -Eq 'release (create|upload|edit|delete-asset)' "${MOCK_STATE}/calls.log"

new_state stable-published-metadata-mismatch
printf 'published archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
touch "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'v1.2.3\n' > "${MOCK_STATE}/release-tag"
printf 'Wrong title\n' > "${MOCK_STATE}/release-title"
printf 'false\n' > "${MOCK_STATE}/prerelease"
printf 'JuliaForm-1.2.3.paclet\n' > "${MOCK_STATE}/assets"
cp -- "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet" \
  "${MOCK_STATE}/asset-files/JuliaForm-1.2.3.paclet"
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
grep -Fq 'has title Wrong title' "${MOCK_STATE}/stderr"
! grep -Eq 'release (create|upload|edit|delete-asset)' "${MOCK_STATE}/calls.log"

new_state stable-published-hash-mismatch
printf 'current archive\n' > "${MOCK_STATE}/dist/JuliaForm-1.2.3.paclet"
touch "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'v1.2.3\n' > "${MOCK_STATE}/release-tag"
printf 'JuliaForm 1.2.3\n' > "${MOCK_STATE}/release-title"
printf 'false\n' > "${MOCK_STATE}/prerelease"
printf 'JuliaForm-1.2.3.paclet\n' > "${MOCK_STATE}/assets"
printf 'stale archive\n' > "${MOCK_STATE}/asset-files/JuliaForm-1.2.3.paclet"
expect_failure bash "${script}" release "${MOCK_STATE}/dist" v1.2.3
grep -Fq 'Published release v1.2.3 asset' "${MOCK_STATE}/stderr"
! grep -Eq 'release (create|upload|edit|delete-asset)' "${MOCK_STATE}/calls.log"

new_state dev-update
printf 'new dev archive\n' > "${MOCK_STATE}/dist/JuliaForm-0.1.0.paclet"
touch "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-0.1.0-dev.old.paclet\n' > "${MOCK_STATE}/assets"
printf 'old-sha\n' > "${MOCK_STATE}/tag"
export GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
bash "${script}" dev "${MOCK_STATE}/dist"
[[ "$(cat "${MOCK_STATE}/tag")" == "${GITHUB_SHA}" ]]
[[ "$(cat "${MOCK_STATE}/assets")" == 'JuliaForm-0.1.0-dev.aaaaaaaaaaaa.paclet' ]]
upload_line="$(grep -n 'release upload' "${MOCK_STATE}/calls.log" | cut -d: -f1)"
download_line="$(grep -n 'release download' "${MOCK_STATE}/calls.log" | cut -d: -f1)"
patch_line="$(grep -n -- '--method PATCH' "${MOCK_STATE}/calls.log" | cut -d: -f1)"
(( upload_line < download_line && download_line < patch_line ))

new_state dev-existing-mismatch
printf 'current dev archive\n' > "${MOCK_STATE}/dist/JuliaForm-0.1.0.paclet"
touch "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-0.1.0-dev.aaaaaaaaaaaa.paclet\n' > "${MOCK_STATE}/assets"
printf 'stale dev archive\n' > \
  "${MOCK_STATE}/asset-files/JuliaForm-0.1.0-dev.aaaaaaaaaaaa.paclet"
printf 'old-sha\n' > "${MOCK_STATE}/tag"
expect_failure bash "${script}" dev "${MOCK_STATE}/dist"
grep -Fq 'has SHA-256' "${MOCK_STATE}/stderr"
[[ "$(cat "${MOCK_STATE}/tag")" == 'old-sha' ]]
! grep -Fq -- '--method PATCH' "${MOCK_STATE}/calls.log"

new_state dev-list-failure
touch "${MOCK_STATE}/dist/JuliaForm-0.1.0.paclet" "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'old-sha\n' > "${MOCK_STATE}/tag"
export MOCK_FAIL_ASSET_LIST=1
expect_failure bash "${script}" dev "${MOCK_STATE}/dist"
grep -Fq 'Unable to list assets' "${MOCK_STATE}/stderr"
[[ "$(cat "${MOCK_STATE}/tag")" == 'old-sha' ]]

new_state dev-patch-recovery
touch "${MOCK_STATE}/dist/JuliaForm-0.1.0.paclet" "${MOCK_STATE}/release"
printf 'false\n' > "${MOCK_STATE}/draft"
printf 'JuliaForm-0.1.0-dev.old.paclet\n' > "${MOCK_STATE}/assets"
printf 'old-sha\n' > "${MOCK_STATE}/tag"
export MOCK_FAIL_PATCH=1
expect_failure bash "${script}" dev "${MOCK_STATE}/dist"
[[ "$(cat "${MOCK_STATE}/tag")" == 'old-sha' ]]
grep -Fxq 'JuliaForm-0.1.0-dev.aaaaaaaaaaaa.paclet' "${MOCK_STATE}/assets"
grep -Fxq 'JuliaForm-0.1.0-dev.old.paclet' "${MOCK_STATE}/assets"
grep -Fq 'release download dev' "${MOCK_STATE}/calls.log"
unset MOCK_FAIL_PATCH
bash "${script}" dev "${MOCK_STATE}/dist"
[[ "$(cat "${MOCK_STATE}/tag")" == "${GITHUB_SHA}" ]]
[[ "$(cat "${MOCK_STATE}/assets")" == 'JuliaForm-0.1.0-dev.aaaaaaaaaaaa.paclet' ]]
[[ "$(grep -Fc 'release download dev' "${MOCK_STATE}/calls.log")" == "2" ]]

echo 'publish-paclet mock tests passed'
