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

The image must provide a noninteractive Linux amd64 `wolframscript`, support
execution as root, and preserve an entrypoint that installs its license or
prepares its environment before forwarding the supplied command.

Create the `dev` and `release` environments before enabling publication.
Restrict `dev` deployments to `main` and `release` deployments to `v*.*.*`
tags. Import `.github/rulesets/protect-main.json` and
`.github/rulesets/protect-version-tags.json`, keep both active without bypass
actors, and apply the payloads under `.github/repository-settings/`. The
selected-actions policy permits GitHub-owned actions plus
`docker/login-action` and `julia-actions/setup-julia`; every workflow reference
is still pinned to a full commit SHA.

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
