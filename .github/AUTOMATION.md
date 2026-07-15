# Repository automation

> [!IMPORTANT]
> Keep this document named `AUTOMATION.md`. A `README` file in `.github/`
> takes precedence over the project-level `README.md` on the repository page.

The `Repository config` CI job runs
`.github/scripts/check-repository-config.sh`. It pins actionlint 1.7.12 to the
SHA-256 published with its official release, checks every workflow shell
script, validates Dependabot and the checked-in repository policy JSON, and
runs the release publisher against the local `gh` mock.

The test matrix uses `.github/scripts/wolfram-runtime.sh` to authenticate to
Docker Hub with an isolated client configuration, pull the private runtime
named by `WOLFRAM_RUNTIME_IMAGE`, and retain only its local image ID. Every
Wolfram command then runs in a fresh root-owned `docker run --rm` container
with the checkout mounted at `/workspace`. The image's native entrypoint is
preserved for license installation and environment initialization, and the
first one-shot container must report Wolfram 15.0.0. The runtime permits
unlimited concurrent instances, so the Julia matrix has no `max-parallel`
throttle and its independent runner jobs may execute together. The workflow
always removes any interrupted container, deletes its local state, and logs
out; it never reads the legacy on-demand entitlement secret. The
repository-config gate exercises this lifecycle against a local Docker mock
without exposing or requiring real credentials.

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

For a local rerun on Linux amd64:

```bash
bash .github/scripts/check-repository-config.sh
```

On another platform, point `ACTIONLINT_BIN` at an executable actionlint 1.7.12
binary; the version is still checked before validation begins.
