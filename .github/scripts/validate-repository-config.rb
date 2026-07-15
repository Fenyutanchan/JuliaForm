#!/usr/bin/env ruby

require "json"
require "yaml"

ROOT = File.expand_path("../..", __dir__)

def fail_check(message)
  warn "repository-config: #{message}"
  exit 1
end

def assert(condition, message)
  fail_check(message) unless condition
end

def load_json(relative_path)
  JSON.parse(File.read(File.join(ROOT, relative_path)))
rescue JSON::ParserError => error
  fail_check("#{relative_path} is invalid JSON: #{error.message}")
end

def assert_exact(actual, expected, relative_path)
  assert(actual == expected, "#{relative_path} does not match its required schema and semantics")
end

settings_directory = File.join(ROOT, ".github/repository-settings")
settings_files = Dir.glob(File.join(settings_directory, "*.json")).sort
expected_settings_files = %w[
  actions-permissions.json
  dev-branch-policy.json
  environment-dev.json
  environment-release.json
  release-tag-policy.json
  selected-actions.json
].map { |name| File.join(settings_directory, name) }.sort
assert(settings_files == expected_settings_files,
       "repository-settings JSON set changed without corresponding validation")

environment_policy = {
  "wait_timer" => 0,
  "prevent_self_review" => false,
  "reviewers" => [],
  "deployment_branch_policy" => {
    "protected_branches" => false,
    "custom_branch_policies" => true
  }
}

expected_settings = {
  ".github/repository-settings/actions-permissions.json" => {
    "enabled" => true,
    "allowed_actions" => "selected",
    "sha_pinning_required" => true
  },
  ".github/repository-settings/dev-branch-policy.json" => {
    "name" => "main",
    "type" => "branch"
  },
  ".github/repository-settings/environment-dev.json" => environment_policy,
  ".github/repository-settings/environment-release.json" => environment_policy,
  ".github/repository-settings/release-tag-policy.json" => {
    "name" => "v*.*.*",
    "type" => "tag"
  },
  ".github/repository-settings/selected-actions.json" => {
    "github_owned_allowed" => true,
    "verified_allowed" => false,
    "patterns_allowed" => ["julia-actions/setup-julia@*"]
  }
}

expected_settings.each do |relative_path, expected|
  assert_exact(load_json(relative_path), expected, relative_path)
end

ruleset_directory = File.join(ROOT, ".github/rulesets")
ruleset_files = Dir.glob(File.join(ruleset_directory, "*.json")).sort
expected_ruleset_files = %w[
  protect-main.json
  protect-version-tags.json
].map { |name| File.join(ruleset_directory, name) }.sort
assert(ruleset_files == expected_ruleset_files,
       "ruleset JSON set changed without corresponding validation")

ruleset_files.each do |path|
  relative_path = path.delete_prefix("#{ROOT}/")
  ruleset = load_json(relative_path)
  assert(ruleset.is_a?(Hash), "#{relative_path} must be a JSON object")
  assert(ruleset["name"].is_a?(String) && !ruleset["name"].empty?,
         "#{relative_path} requires a non-empty name")
  assert(%w[branch tag].include?(ruleset["target"]),
         "#{relative_path} target must be branch or tag")
  assert(%w[active disabled evaluate].include?(ruleset["enforcement"]),
         "#{relative_path} has an invalid enforcement value")
  assert(ruleset.dig("conditions", "ref_name", "include").is_a?(Array),
         "#{relative_path} requires conditions.ref_name.include")
  assert(ruleset.dig("conditions", "ref_name", "exclude").is_a?(Array),
         "#{relative_path} requires conditions.ref_name.exclude")
  assert(ruleset["rules"].is_a?(Array) && !ruleset["rules"].empty?,
         "#{relative_path} requires at least one rule")
  assert(ruleset["rules"].all? { |rule| rule.is_a?(Hash) && rule["type"].is_a?(String) },
         "#{relative_path} contains a malformed rule")
  assert(ruleset["bypass_actors"].is_a?(Array),
         "#{relative_path} requires a bypass_actors array")
end

assert_exact(
  load_json(".github/rulesets/protect-main.json"),
  {
    "name" => "Protect Main",
    "target" => "branch",
    "enforcement" => "active",
    "conditions" => {
      "ref_name" => { "exclude" => [], "include" => ["refs/heads/main"] }
    },
    "rules" => [
      { "type" => "deletion" },
      { "type" => "non_fast_forward" },
      {
        "type" => "required_status_checks",
        "parameters" => {
          "do_not_enforce_on_create" => true,
          "required_status_checks" => [
            { "context" => "CI summary", "integration_id" => 15_368 }
          ],
          "strict_required_status_checks_policy" => true
        }
      }
    ],
    "bypass_actors" => []
  },
  ".github/rulesets/protect-main.json"
)

assert_exact(
  load_json(".github/rulesets/protect-version-tags.json"),
  {
    "name" => "Protect Version Tags",
    "target" => "tag",
    "enforcement" => "active",
    "conditions" => {
      "ref_name" => { "exclude" => [], "include" => ["refs/tags/v*"] }
    },
    "rules" => [
      {
        "type" => "update",
        "parameters" => { "update_allows_fetch_and_merge" => false }
      },
      { "type" => "deletion" }
    ],
    "bypass_actors" => []
  },
  ".github/rulesets/protect-version-tags.json"
)

dependabot_path = File.join(ROOT, ".github/dependabot.yml")
dependabot = YAML.safe_load(
  File.read(dependabot_path),
  permitted_classes: [],
  permitted_symbols: [],
  aliases: false
)
assert(dependabot.is_a?(Hash) && dependabot["version"] == 2,
       ".github/dependabot.yml must use version 2")
updates = dependabot["updates"]
assert(updates.is_a?(Array) && updates.length == 1,
       ".github/dependabot.yml must contain exactly one update policy")
update = updates.first
assert(update["package-ecosystem"] == "github-actions" && update["directory"] == "/",
       "Dependabot must update GitHub Actions from the repository root")
assert(update.dig("schedule", "interval") == "weekly",
       "Dependabot GitHub Actions updates must run weekly")

workflow_paths = Dir.glob(File.join(ROOT, ".github/workflows/*.{yml,yaml}")).sort
assert(!workflow_paths.empty?, "repository must contain at least one workflow")
workflow_paths.each do |path|
  relative_path = path.delete_prefix("#{ROOT}/")
  contents = File.read(path)
  assert(!contents.include?("pull_request_target:"),
         "pull_request_target is forbidden: #{relative_path}")

  contents.lines.map do |line|
    match = line.match(/^\s*uses:\s*([^\s#]+)/)
    match && match[1]
  end.compact.each do |use|
    repository, revision = use.split("@", 2)
    assert(repository.start_with?("actions/") || repository == "julia-actions/setup-julia",
           "non-approved remote action in #{relative_path}: #{use}")
    assert(revision&.match?(/\A[0-9a-f]{40}\z/),
           "remote action is not pinned to a full commit SHA in #{relative_path}: #{use}")
  end
end

workflow_path = File.join(ROOT, ".github/workflows/CI.yml")
workflow = File.read(workflow_path)

required_workflow_fragments = [
  "repository-config:",
  "needs.repository-config.result == 'success'",
  "REPOSITORY_CONFIG_RESULT: ${{ needs.repository-config.result }}",
  'if [[ "${REPOSITORY_CONFIG_RESULT}" != "success" ]]',
  "julia --startup-file=no --check-bounds=yes Tests/JuliaValidation.jl"
]
required_workflow_fragments.each do |fragment|
  assert(workflow.include?(fragment), "CI workflow is missing repository-config gate: #{fragment}")
end

repository_config_block = workflow[/^  repository-config:\n(.*?)(?=^  [a-z][a-z0-9-]*:\n|\z)/m, 1]
assert(repository_config_block, "CI workflow is missing the repository-config job body")
assert(repository_config_block.include?("contents: read"),
       "repository-config job must have contents: read")
assert(!repository_config_block.include?("secrets."),
       "repository-config job must not read secrets")

puts "Repository settings, rulesets, Dependabot, and workflow policy are valid."
