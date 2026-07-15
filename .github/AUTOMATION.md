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
named by `WOLFRAM_RUNTIME_IMAGE`, and execute every Wolfram command in one
root-owned container with the checkout mounted at `/workspace`. Startup fails
unless the runtime reports Wolfram 15.0.0. The workflow always removes the
container and logs out; it never reads the legacy on-demand entitlement secret.
The repository-config gate exercises this lifecycle against a local Docker
mock without exposing or requiring real credentials.

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
