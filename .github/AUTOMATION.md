# Repository automation

> [!IMPORTANT]
> Keep this document named `AUTOMATION.md`. A `README` file in `.github/`
> takes precedence over the project-level `README.md` on the repository page.

## Private Wolfram runtime

The CI matrix uses Docker's official `docker/login-action`, pinned to a full
commit SHA, to authenticate to Docker Hub. Its default post-job hook logs out.
`.github/scripts/wolfram-runtime.sh` pulls the private image named by
`WOLFRAM_RUNTIME_IMAGE`, tags it with a local non-secret alias, and verifies
that its first one-shot container reports Wolfram 15.0.0.

Every Wolfram command runs as root in a fresh `docker run --rm` container with
the checkout mounted at `/workspace`. The image's native entrypoint is
preserved so it can install the license or initialize its environment before
forwarding the command. The runtime supports unlimited concurrent instances,
so the two Julia matrix jobs may run at the same time. Secret-dependent tests
are skipped for pull requests from forks; a maintainer must retest such a
change from a branch in this repository.

## Required repository configuration

Configure these repository Actions secrets before the first run:

| Secret | Required value |
| --- | --- |
| `WOLFRAM_RUNTIME_IMAGE` | Complete Docker reference for the private Wolfram 15.0.0 image; prefer `namespace/repository@sha256:...` |
| `DOCKERHUB_USERNAME` | Docker Hub account allowed to pull that image |
| `DOCKERHUB_TOKEN` | Read-only Docker Hub access token for that account |
| `REPOSITORY_SETTINGS_TOKEN` | Fine-grained personal access token limited to this repository, with repository `Administration: Read and write` and `Actions: Read` permissions |

The image must provide a noninteractive Linux amd64 `wolframscript`, support
execution as root, and preserve an entrypoint that prepares its license and
environment before forwarding the supplied command.

The default workflow `GITHUB_TOKEN` cannot administer repository settings.
Use a fine-grained `REPOSITORY_SETTINGS_TOKEN` restricted to this repository
and rotate it before expiry.

The `Repository settings` workflow runs on `main` when its workflow, sync
script, settings payloads, or rulesets change. It may also be dispatched
manually from `main`. `.github/scripts/apply-repository-settings.sh` uses the
runner's `gh` CLI to apply Actions permissions, the selected-actions allowlist,
the `dev` and `release` environments, and both named rulesets. Environment
deployment policies are made exact; unrelated rulesets are left untouched.
Repeated runs are idempotent.

The selected-actions policy permits GitHub-owned actions plus
`docker/login-action` and `julia-actions/setup-julia`. Every workflow reference
is still pinned to a full commit SHA. Apply an allowlist change before relying
on a newly permitted external action.

## Publishing

The Julia `1` matrix job builds and validates one canonical archive such as
`JuliaForm-1.2.3.paclet`, then uploads it as a short-lived workflow artifact.
Only the two publisher jobs receive `contents: write` permission.

For a push to `main`, the `dev` publisher replaces the disposable rolling
prerelease and its tag with a release for the tested commit. If that operation
is interrupted, the next successful `main` run recreates it. The canonical
archive filename is preserved.

For a strict `vMAJOR.MINOR.PATCH` tag, the stable publisher verifies that the
tag already exists and that the archive filename matches the tag before
creating the GitHub Release. A published stable release is never rewritten.
If publication is interrupted and leaves an incomplete draft, delete only
that draft and rerun the tag workflow; never move, delete, or reuse a published
version tag.
