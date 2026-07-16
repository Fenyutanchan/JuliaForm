#!/usr/bin/env bash

set -Eeuo pipefail

readonly GITHUB_API_VERSION="2026-03-10"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd -- "${script_directory}/../.." && pwd)"
settings_directory="${repository_root}/.github/repository-settings"
ruleset_directory="${repository_root}/.github/rulesets"

api() {
  gh api \
    --header "Accept: application/vnd.github+json" \
    --header "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "$@"
}

put_json() {
  api --method PUT "$1" --input "$2" >/dev/null
}

sync_environment() {
  local environment_name="$1"
  local policy_file="$2"
  local policies=""
  local policy_id=""

  put_json \
    "repos/${GH_REPO}/environments/${environment_name}" \
    "${settings_directory}/environment-${environment_name}.json"

  policies="$(
    api \
      "repos/${GH_REPO}/environments/${environment_name}/deployment-branch-policies?per_page=100"
  )"

  if jq -e --slurpfile desired "${policy_file}" '
    .total_count == 1 and
    .branch_policies[0].name == $desired[0].name and
    .branch_policies[0].type == $desired[0].type
  ' <<< "${policies}" >/dev/null; then
    return
  fi

  while IFS= read -r policy_id; do
    api --method DELETE \
      "repos/${GH_REPO}/environments/${environment_name}/deployment-branch-policies/${policy_id}" \
      >/dev/null
  done < <(jq -r '.branch_policies[].id | numbers' <<< "${policies}")

  api --method POST \
    "repos/${GH_REPO}/environments/${environment_name}/deployment-branch-policies" \
    --input "${policy_file}" >/dev/null
}

: "${GH_TOKEN:?REPOSITORY_SETTINGS_TOKEN is unavailable}"
: "${GH_REPO:?GH_REPO is unavailable}"

cd -- "${repository_root}"

put_json \
  "repos/${GH_REPO}/actions/permissions" \
  "${settings_directory}/actions-permissions.json"
put_json \
  "repos/${GH_REPO}/actions/permissions/selected-actions" \
  "${settings_directory}/selected-actions.json"

sync_environment \
  "dev" \
  "${settings_directory}/dev-branch-policy.json"
sync_environment \
  "release" \
  "${settings_directory}/release-tag-policy.json"

rulesets="$(api "repos/${GH_REPO}/rulesets?includes_parents=false&per_page=100")"
for ruleset_file in "${ruleset_directory}"/*.json; do
  ruleset_name="$(jq -er '.name' "${ruleset_file}")"
  ruleset_id="$(
    jq -r --arg name "${ruleset_name}" '
      [.[] | select(.name == $name) | .id] |
      if length > 1 then error("duplicate managed ruleset") else .[0] // empty end
    ' <<< "${rulesets}"
  )"

  if [[ -n "${ruleset_id}" ]]; then
    api --method PUT "repos/${GH_REPO}/rulesets/${ruleset_id}" \
      --input "${ruleset_file}" >/dev/null
  else
    api --method POST "repos/${GH_REPO}/rulesets" \
      --input "${ruleset_file}" >/dev/null
  fi
done

echo "Repository settings: all checked-in configuration is applied."
