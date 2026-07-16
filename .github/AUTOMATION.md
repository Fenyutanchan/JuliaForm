# Repository automation

> [!IMPORTANT]
> Keep this document named `AUTOMATION.md`. A `README` file in `.github/`
> takes precedence over the project-level `README.md` on the repository page.

## Validation

The `Repository config` CI job runs
`.github/scripts/check-repository-config.sh`. It pins actionlint 1.7.12 to the
SHA-256 published with its official release, checks every workflow shell
script, validates Dependabot and the checked-in repository policy JSON, and
runs the release publisher against the local `gh` mock.

## Private Wolfram runtime

The test matrix delegates Docker Hub authentication to Docker's official
`docker/login-action`, pinned to a full commit SHA and configured to log out in
its post-job hook. `.github/scripts/wolfram-runtime.sh` then pulls the private
runtime named by `WOLFRAM_RUNTIME_IMAGE` without reading registry credentials
and retains only its local image ID. Every Wolfram command runs in a fresh
root-owned `docker run --rm` container with the checkout mounted at
`/workspace`. The image's native entrypoint is preserved for license
installation and environment initialization, and the first one-shot container
must report Wolfram 15.0.0. The runtime permits unlimited concurrent instances,
so the Julia matrix has no `max-parallel` throttle and its independent runner
jobs may execute together. The workflow always removes any interrupted
container and deletes its local runtime state; it never reads the legacy
on-demand entitlement secret. The repository-config gate checks the
authentication boundary statically; registry login and the runtime lifecycle
are exercised directly by the test jobs in GitHub Actions.

## Required repository configuration

Configure these repository Actions secrets before the first run:

| Secret | Required value |
| --- | --- |
| `WOLFRAM_RUNTIME_IMAGE` | Complete Docker reference for the private Wolfram 15.0.0 image; prefer `namespace/repository@sha256:...` |
| `DOCKERHUB_USERNAME` | Docker Hub account allowed to pull that image |
| `DOCKERHUB_TOKEN` | Read-only Docker Hub access token for that account |
| `REPOSITORY_SETTINGS_TOKEN` | Fine-grained personal access token limited to this repository, with repository `Administration: Read and write` and `Actions: Read` permissions |

The image must provide a noninteractive Linux amd64 `wolframscript`, support
execution as root, and preserve an entrypoint that installs its license or
prepares its environment before forwarding the supplied command.

The default workflow `GITHUB_TOKEN` cannot administer repository settings.
Create `REPOSITORY_SETTINGS_TOKEN` as a fine-grained token, grant access only
to this repository, store it as an Actions secret, and rotate it before its
expiry. A classic token with the broad `repo` scope also works, but is not the
recommended credential.

The `Repository settings` workflow runs when the checked-in settings, rulesets,
sync script, validator, or workflow changes on `main`. It can also be dispatched
manually from `main`; dispatches from any other ref are skipped so an untrusted
revision cannot receive the administration token. The workflow first runs the
fail-closed repository validator and then delegates to
`.github/scripts/apply-repository-settings.sh`. That script uses the `gh` CLI
preinstalled on GitHub-hosted runners and performs every write through
`gh api`; it does not implement a separate HTTP client.

The sync script applies Actions permissions and the selected-actions policy,
creates or updates the `dev` and `release` environments, and makes their custom
deployment policies exact: only `main` may deploy to `dev`, and only `v*.*.*`
tags may deploy to `release`. Extra deployment policies are removed because
they would widen the declared deployment boundary. The two checked-in rulesets
are created or updated by their stable names; unrelated repository rulesets are
left untouched. Repeated runs are idempotent.

The selected-actions policy permits GitHub-owned actions plus
`docker/login-action` and `julia-actions/setup-julia`; every workflow reference
is still pinned to a full commit SHA. If a change introduces another external
action, apply its allowlist change before relying on that action in a later
commit, because GitHub evaluates the allowlist before any job in the dependent
workflow can start.

Repository secrets are unavailable to pull requests from forks. Their summary
job fails explicitly until a maintainer retests the commit from a branch in the
base repository; never use `pull_request_target` to execute pull-request code.

## Publishing

Stable releases preserve the paclet name produced by `Scripts/BuildPaclet.wls`,
for example `JuliaForm-1.2.3.paclet`. The rolling `dev` publisher copies that
same built archive to a commit-unique release-asset name such as
`JuliaForm-1.2.3-dev.0123456789ab.paclet`. This is a publication-layer rename:
the builder and the downloaded workflow artifact retain the canonical paclet
filename. Before moving the `dev` tag, the publisher downloads the renamed
asset and verifies that its SHA-256 matches the built archive.

If a stable release is already published, a rerun is read-only. It succeeds
only when the release tag and title are canonical, the release is not a
prerelease, exactly one canonical asset exists, and that asset's SHA-256
matches the local archive. This covers a lost final API response without ever
rewriting a published release.

## Local validation

For a local rerun on Linux amd64:

```bash
bash .github/scripts/check-repository-config.sh
```

On another platform, point `ACTIONLINT_BIN` at an executable actionlint 1.7.12
binary; the version is still checked before validation begins.
