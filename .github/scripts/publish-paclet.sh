#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s nullglob

archive=""
asset_name=""
calculated_sha256=""
release_assets=""
release_exists=false
release_is_draft=false
temporary_directory=""

usage() {
  cat >&2 <<'EOF'
Usage:
  publish-paclet.sh dev ARTIFACT_DIRECTORY
  publish-paclet.sh release ARTIFACT_DIRECTORY TAG
EOF
}

fail() {
  echo "::error::$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${temporary_directory}" && -d "${temporary_directory}" ]]; then
    rm -rf -- "${temporary_directory}"
  fi
}

trap cleanup EXIT

require_environment() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Required environment variable is missing: ${name}"
}

require_command() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || fail "Required command is unavailable: ${name}"
}

select_archive() {
  local artifact_directory="$1"
  local archives

  [[ -d "${artifact_directory}" ]] || fail "Artifact directory does not exist: ${artifact_directory}"
  archives=("${artifact_directory}"/*.paclet)

  if (( ${#archives[@]} != 1 )); then
    fail "Expected exactly one paclet archive, found ${#archives[@]}"
  fi

  archive="${archives[0]}"
  asset_name="${archive##*/}"
}

lookup_release() {
  local tag="$1"
  local error_file="${temporary_directory}/release-view.err"
  local state=""

  : > "${error_file}"
  if state="$(
    gh release view "${tag}" --json isDraft --jq '.isDraft' 2>"${error_file}"
  )"; then
    case "${state}" in
      true|false)
        release_exists=true
        release_is_draft="${state}"
        ;;
      *)
        fail "Unexpected draft state for release ${tag}: ${state}"
        ;;
    esac
    return
  fi

  if grep -Eiq 'HTTP 404|no release found|release not found|not found' "${error_file}"; then
    release_exists=false
    release_is_draft=false
    return
  fi

  sed 's/^/gh: /' "${error_file}" >&2
  fail "Unable to query release ${tag}"
}

load_release_assets() {
  local tag="$1"
  local error_file="${temporary_directory}/release-assets.err"

  : > "${error_file}"
  if ! release_assets="$(
    gh release view "${tag}" --json assets --jq '.assets[].name' 2>"${error_file}"
  )"; then
    sed 's/^/gh: /' "${error_file}" >&2
    fail "Unable to list assets for release ${tag}"
  fi
}

asset_list_contains() {
  local assets="$1"
  local expected="$2"
  local existing=""

  while IFS= read -r existing; do
    [[ -n "${existing}" ]] || continue
    [[ "${existing}" == "${expected}" ]] && return 0
  done <<< "${assets}"

  return 1
}

ensure_dev_asset() {
  local tag="$1"
  local path="$2"
  local name="${path##*/}"

  load_release_assets "${tag}"
  if asset_list_contains "${release_assets}" "${name}"; then
    echo "Found existing dev asset ${name}; verifying its content before reuse."
  else
    gh release upload "${tag}" "${path}"
  fi

  # A same-name asset can be left by an interrupted attempt. Never move the
  # rolling tag until the server-side bytes are proven to match this commit.
  verify_remote_asset "${tag}" "${path}" "dev-asset" "Dev release"
}

calculate_sha256() {
  local path="$1"
  local output=""

  if ! output="$(sha256sum -- "${path}")"; then
    fail "Unable to calculate SHA-256 for ${path}"
  fi

  calculated_sha256="${output%% *}"
  [[ "${calculated_sha256}" =~ ^[0-9a-fA-F]{64}$ ]] ||
    fail "Unexpected SHA-256 output for ${path}: ${output}"
}

verify_remote_asset() {
  local tag="$1"
  local path="$2"
  local directory_name="$3"
  local release_label="$4"
  local name="${path##*/}"
  local download_directory="${temporary_directory}/${directory_name}"
  local downloaded_archive="${download_directory}/${name}"
  local local_sha256=""
  local remote_sha256=""

  mkdir -p -- "${download_directory}"
  gh release download "${tag}" \
    --pattern "${name}" \
    --dir "${download_directory}"

  [[ -f "${downloaded_archive}" ]] ||
    fail "Downloaded ${release_label} asset is missing: ${name}"

  calculate_sha256 "${path}"
  local_sha256="${calculated_sha256}"
  calculate_sha256 "${downloaded_archive}"
  remote_sha256="${calculated_sha256}"

  if [[ "${local_sha256}" != "${remote_sha256}" ]]; then
    fail "${release_label} ${tag} asset ${name} has SHA-256 ${remote_sha256}, expected ${local_sha256}"
  fi

  echo "Verified SHA-256 ${local_sha256} for ${name}."
}

ensure_stable_asset() {
  local tag="$1"
  local path="$2"
  local name="${path##*/}"

  load_release_assets "${tag}"
  if asset_list_contains "${release_assets}" "${name}"; then
    echo "Found existing draft asset ${name}; verifying its content before publication."
  else
    gh release upload "${tag}" "${path}"
  fi

  # Download and hash even a fresh upload. This makes draft recovery safe and
  # verifies that the server-side asset matches the archive being published.
  verify_remote_asset "${tag}" "${path}" "stable-asset" "Draft release"
}

update_dev_tag() {
  local tag="$1"
  local sha="$2"
  local error_file="${temporary_directory}/tag-view.err"
  local status=0

  : > "${error_file}"
  gh api "repos/${GH_REPO}/git/ref/tags/${tag}" >/dev/null 2>"${error_file}" || status=$?

  case "${status}" in
    0)
      gh api --method PATCH \
        "repos/${GH_REPO}/git/refs/tags/${tag}" \
        -f sha="${sha}" \
        -F force=true \
        >/dev/null
      ;;
    *)
      if grep -Eiq 'HTTP 404|not found' "${error_file}"; then
        gh api --method POST \
          "repos/${GH_REPO}/git/refs" \
          -f ref="refs/tags/${tag}" \
          -f sha="${sha}" \
          >/dev/null
      else
        sed 's/^/gh: /' "${error_file}" >&2
        fail "Unable to query tag ${tag}"
      fi
      ;;
  esac
}

remove_stale_dev_assets() {
  local tag="$1"
  local current_asset="$2"
  local existing=""

  load_release_assets "${tag}"
  asset_list_contains "${release_assets}" "${current_asset}" ||
    fail "Current dev asset is missing after upload: ${current_asset}"

  while IFS= read -r existing; do
    [[ -n "${existing}" ]] || continue
    if [[ "${existing}" == *.paclet && "${existing}" != "${current_asset}" ]]; then
      gh release delete-asset "${tag}" "${existing}" --yes
    fi
  done <<< "${release_assets}"
}

validate_stable_assets() {
  local tag="$1"
  local expected="$2"
  local existing=""
  local count=0

  load_release_assets "${tag}"
  while IFS= read -r existing; do
    [[ -n "${existing}" ]] || continue
    (( count += 1 ))
    [[ "${existing}" == "${expected}" ]] ||
      fail "Draft release ${tag} contains unexpected asset: ${existing}"
  done <<< "${release_assets}"

  (( count == 1 )) ||
    fail "Draft release ${tag} must contain exactly one asset: ${expected}"
}

verify_published_stable_release() {
  local tag="$1"
  local expected_asset="$2"
  local expected_title="$3"
  local path="$4"
  local error_file="${temporary_directory}/published-release.err"
  local metadata=""
  local actual_tag=""
  local actual_title=""
  local actual_draft=""
  local actual_prerelease=""
  local extra_field=""
  local existing=""
  local asset_count=0

  : > "${error_file}"
  if ! metadata="$(
    gh release view "${tag}" \
      --json tagName,name,isDraft,isPrerelease \
      --jq '[.tagName, .name, .isDraft, .isPrerelease] | @tsv' \
      2>"${error_file}"
  )"; then
    sed 's/^/gh: /' "${error_file}" >&2
    fail "Unable to read published release metadata for ${tag}"
  fi

  IFS=$'\t' read -r actual_tag actual_title actual_draft actual_prerelease extra_field <<< "${metadata}"
  [[ -z "${extra_field}" ]] || fail "Unexpected published release metadata for ${tag}: ${metadata}"
  [[ "${actual_tag}" == "${tag}" ]] ||
    fail "Published release ${tag} reports tag ${actual_tag}"
  [[ "${actual_title}" == "${expected_title}" ]] ||
    fail "Published release ${tag} has title ${actual_title}, expected ${expected_title}"
  [[ "${actual_draft}" == "false" ]] ||
    fail "Published release ${tag} unexpectedly reports isDraft=${actual_draft}"
  [[ "${actual_prerelease}" == "false" ]] ||
    fail "Published release ${tag} unexpectedly reports isPrerelease=${actual_prerelease}"

  load_release_assets "${tag}"
  while IFS= read -r existing; do
    [[ -n "${existing}" ]] || continue
    (( asset_count += 1 ))
    [[ "${existing}" == "${expected_asset}" ]] ||
      fail "Published release ${tag} contains unexpected asset: ${existing}"
  done <<< "${release_assets}"
  (( asset_count == 1 )) ||
    fail "Published release ${tag} must contain exactly one asset: ${expected_asset}"

  # This path is intentionally read-only. It handles the case where GitHub
  # published the draft but the final API response was lost or ambiguous.
  verify_remote_asset "${tag}" "${path}" "published-stable-asset" "Published release"
  echo "Published release ${tag} already matches the requested artifact; no changes required."
}

publish_dev() {
  local artifact_directory="$1"
  local tag="dev"
  local title="Development build"
  local short_sha="${GITHUB_SHA:0:12}"
  local notes="Automated development build from commit ${GITHUB_SHA}."
  local staged_asset_name=""
  local staged_archive=""

  select_archive "${artifact_directory}"
  staged_asset_name="${asset_name%.paclet}-dev.${short_sha}.paclet"
  staged_archive="${temporary_directory}/${staged_asset_name}"
  cp -- "${archive}" "${staged_archive}"

  lookup_release "${tag}"
  if [[ "${release_exists}" != "true" ]]; then
    gh release create "${tag}" \
      --target "${GITHUB_SHA}" \
      --title "${title}" \
      --notes "${notes}" \
      --prerelease \
      --draft
    release_is_draft=true
  fi

  # Upload a commit-unique asset while the old tag and old asset remain usable.
  # If a later command fails, rerunning the same commit reuses this upload.
  ensure_dev_asset "${tag}" "${staged_archive}"

  gh release edit "${tag}" \
    --title "${title}" \
    --notes "${notes}" \
    --prerelease \
    --latest=false

  # Move the rolling tag only after the new asset and metadata are available.
  update_dev_tag "${tag}" "${GITHUB_SHA}"

  if [[ "${release_is_draft}" == "true" ]]; then
    gh release edit "${tag}" \
      --draft=false \
      --prerelease \
      --latest=false
  fi

  # Cleanup is deliberately last. A cleanup interruption leaves extra assets,
  # not a tag that points at a commit whose asset was never uploaded.
  remove_stale_dev_assets "${tag}" "${staged_asset_name}"
}

publish_release() {
  local artifact_directory="$1"
  local tag="$2"
  local version=""
  local expected_asset=""
  local title=""
  local notes=""

  if [[ ! "${tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    fail "Release tag must use canonical vMAJOR.MINOR.PATCH SemVer: ${tag}"
  fi

  version="${tag#v}"
  expected_asset="JuliaForm-${version}.paclet"
  title="JuliaForm ${version}"
  notes="Automated release for ${tag} from commit ${GITHUB_SHA}."

  select_archive "${artifact_directory}"
  if [[ "${asset_name}" != "${expected_asset}" ]]; then
    fail "Tag ${tag} requires ${expected_asset}, found ${asset_name}"
  fi

  lookup_release "${tag}"
  if [[ "${release_exists}" == "true" && "${release_is_draft}" != "true" ]]; then
    verify_published_stable_release "${tag}" "${expected_asset}" "${title}" "${archive}"
    return
  fi

  if [[ "${release_exists}" != "true" ]]; then
    gh release create "${tag}" \
      --verify-tag \
      --title "${title}" \
      --notes "${notes}" \
      --draft
  else
    gh release edit "${tag}" \
      --title "${title}" \
      --notes "${notes}"
  fi

  ensure_stable_asset "${tag}" "${archive}"
  validate_stable_assets "${tag}" "${expected_asset}"

  gh release edit "${tag}" \
    --draft=false \
    --prerelease=false
}

if (( $# < 2 )); then
  usage
  exit 2
fi

mode="$1"
artifact_directory="$2"
shift 2

require_environment GH_TOKEN
require_environment GH_REPO
require_environment GITHUB_SHA
[[ "${GITHUB_SHA}" =~ ^[0-9a-fA-F]{40}$ ]] || fail "GITHUB_SHA must be a 40-character hexadecimal commit ID"

require_command gh
require_command mktemp
require_command cp
require_command mkdir
require_command sha256sum
temporary_directory="$(mktemp -d)"

case "${mode}" in
  dev)
    (( $# == 0 )) || fail "The dev mode does not accept a tag argument"
    publish_dev "${artifact_directory}"
    ;;
  release)
    (( $# == 1 )) || fail "The release mode requires exactly one tag argument"
    publish_release "${artifact_directory}" "$1"
    ;;
  *)
    usage
    fail "Unknown publication mode: ${mode}"
    ;;
esac
