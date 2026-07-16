#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s nullglob

fail() {
  echo "::error::$*" >&2
  exit 1
}

if (( $# < 2 )); then
  fail "usage: ${0##*/} {dev|release} ARTIFACT_DIRECTORY [TAG]"
fi

mode="$1"
artifact_directory="$2"
shift 2

: "${GH_TOKEN:?GH_TOKEN is unavailable}"
: "${GH_REPO:?GH_REPO is unavailable}"
: "${GITHUB_SHA:?GITHUB_SHA is unavailable}"
[[ "${GITHUB_SHA}" =~ ^[0-9a-fA-F]{40}$ ]] ||
  fail "GITHUB_SHA must be a 40-character hexadecimal commit ID"
[[ -d "${artifact_directory}" ]] ||
  fail "artifact directory does not exist: ${artifact_directory}"

archives=("${artifact_directory}"/*.paclet)
(( ${#archives[@]} == 1 )) ||
  fail "expected exactly one paclet archive, found ${#archives[@]}"
archive="${archives[0]}"
asset_name="${archive##*/}"

case "${mode}" in
  dev)
    (( $# == 0 )) || fail "dev mode does not accept a tag"

    # The rolling prerelease is disposable. Recreate it instead of maintaining
    # a second release transaction and recovery protocol in this repository.
    gh release delete dev --cleanup-tag --yes >/dev/null 2>&1 || true
    gh api --method DELETE "repos/${GH_REPO}/git/refs/tags/dev" \
      >/dev/null 2>&1 || true
    gh release create dev "${archive}" \
      --target "${GITHUB_SHA}" \
      --title "Development build" \
      --notes "Automated development build from commit ${GITHUB_SHA}." \
      --prerelease \
      --latest=false
    ;;
  release)
    (( $# == 1 )) || fail "release mode requires exactly one tag"
    tag="$1"
    [[ "${tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
      fail "release tag must use canonical vMAJOR.MINOR.PATCH SemVer: ${tag}"

    version="${tag#v}"
    expected_asset="JuliaForm-${version}.paclet"
    [[ "${asset_name}" == "${expected_asset}" ]] ||
      fail "tag ${tag} requires ${expected_asset}, found ${asset_name}"

    gh release create "${tag}" "${archive}" \
      --verify-tag \
      --title "JuliaForm ${version}" \
      --notes "Automated release for ${tag} from commit ${GITHUB_SHA}."
    ;;
  *)
    fail "unknown publication mode: ${mode}"
    ;;
esac
