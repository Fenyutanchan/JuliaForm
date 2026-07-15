# Contributing to JuliaForm

**English** | [简体中文](CONTRIBUTING_zh-CN.md)

> [!NOTE]
> This file is the canonical contribution guide. Its Simplified Chinese
> counterpart is a rigorous translation, not an independently maintained
> specification.

Thanks for your interest in improving `JuliaForm`! This document describes
the local development workflow, the correctness requirements for Wolfram-to-
Julia rendering, and the commit message convention used by this repository.

`JuliaForm` is a Wolfram Language 15.0+ Paclet. It renders Wolfram Language
expressions as deterministic, single-line Julia source and exposes exactly
one public symbol: `JuliaForm`. The implementation is intentionally small,
but changes require care because syntactically valid output can still have
different evaluation, numeric, array, or indexing semantics in Julia.

## Design Requirements

Correctness takes priority over the number of expressions accepted. A change
to the renderer must preserve these invariants:

- Keep `JuliaForm` as the only public symbol in the `JuliaForm` context.
- Preserve ordinary Wolfram Language evaluation. Use `HoldForm` only where
  callers explicitly need to retain arithmetic structure.
- Emit deterministic, single-line UTF-8 Julia source.
- Preserve exact values where Julia has a faithful representation, including
  integers, rationals, complex numbers, and arbitrary-precision reals.
- Track Julia operator precedence explicitly. Do not rely on visually
  plausible output when parentheses affect the parsed expression.
- Account for semantic differences between the two languages, especially
  argument order, list threading, array operations, equality, and indexing.
- Reject a construct with `JuliaForm::unsupported` when a general translation
  would be misleading. Do not add a convenient-looking mapping without a
  defensible cross-language equivalence.
- Keep `Rule` documented and tested as Julia `Pair` construction, not as a
  Wolfram Language rewrite rule.

Unknown symbolic heads may continue to render as Julia calls when no special
mapping is required. By contrast, type-sensitive built-ins such as `Total`,
`Length`, `Transpose`, and `Norm` must not be renamed merely because Julia has
a similarly named operation.

## Documentation and Translation Policy

English is the canonical source language for project documentation. The
maintained documentation pairs are:

| Canonical English source | Simplified Chinese translation |
|---|---|
| `README.md` | `README_zh-CN.md` |
| `CONTRIBUTING.md` | `CONTRIBUTING_zh-CN.md` |
| `Documentation/English/ReferencePages/Symbols/JuliaForm.nb` | `Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb` |

New user or contributor documentation must follow the same convention:
English Markdown uses the unsuffixed canonical filename, its translation adds
`_zh-CN` before the extension, and native Wolfram documentation is paired
between `Documentation/English` and `Documentation/ChineseSimplified`.

Every documentation change must follow this order:

1. Edit the canonical English file first.
2. Establish the technical accuracy and intended normative meaning of the
   English text.
3. Update the paired Simplified Chinese file in the same change.
4. Audit the translation against the final English source, including heading
   order, examples, code, links, exact identifiers, version numbers,
   requirements, supported behavior, and limitations.
5. Run the documentation parity checks together with the ordinary test suite.

The Chinese version must preserve all normative content and technical detail.
Do not omit qualifications, weaken requirements, or add independent technical
claims. A short translator clarification is acceptable only when it preserves
the English meaning. Code, identifiers, literal output, paths, versions, and
commands must remain verbatim unless the text itself is the item being
translated.

If the two versions conflict or are ambiguous, the English source prevails.
Repair the Chinese translation in the same change that discovers the drift. A
documentation change is incomplete while its paired translation is stale.
Automated parity checks protect structure and code examples, but they do not
replace a human review for accurate, complete, and idiomatic translation.

## Development Setup

The repository is a Wolfram Paclet, not a Julia package. It therefore has no
`Project.toml`, registry, or package-instantiation step.

Install the following tools:

1. Wolfram Language 15.0 or later, including `PacletTools`.
2. Julia's LTS and latest stable releases to reproduce the full CI matrix.
3. `wolframscript` for tests, validation generation, and Paclet builds.

The repository does not assume an operating system or a Wolfram installation
path. Ensure `wolframscript` and `julia` are available on `PATH` before running
the commands below. If `wolframscript` cannot locate a kernel, either run
`wolframscript -configure` once or set its documented environment variable for
the current shell:

```bash
export WolframKernel=/absolute/path/to/WolframKernel
```

To load a checkout directly in a Wolfram Language session:

```wl
Needs["PacletTools`"];
PacletDirectoryLoad["/absolute/path/to/JuliaForm"];
Needs["JuliaForm`"];
```

Use a fresh kernel after changing package initialization or output-form
registration so an earlier directory load does not hide a lifecycle bug.

## Repository Layout

| Path | Purpose |
|------|---------|
| `PacletInfo.wl` | Paclet name, version, compatibility, and extensions |
| `Kernel/init.wl` | SPF initialization and public-symbol protection |
| `Kernel/JuliaForm.wl` | Renderer and the sole exported API |
| `Documentation/English/ReferencePages/Symbols/JuliaForm.nb` | Canonical native symbol reference page |
| `Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb` | Simplified Chinese translation of the symbol page |
| `README.md` / `README_zh-CN.md` | Canonical user guide and its translation |
| `CONTRIBUTING.md` / `CONTRIBUTING_zh-CN.md` | Canonical contribution guide and its translation |
| `LICENSE` | MIT license distributed with the source and Paclet archive |
| `Tests/JuliaForm.wlt` | Wolfram Language unit and contract tests |
| `Tests/RunTests.wls` | Fresh-kernel Wolfram test runner |
| `Tests/JuliaValidation.wls` | Generates Julia source from test expressions |
| `Tests/JuliaValidation.jl` | Parses and evaluates generated Julia source |
| `Tests/ValidatePacletArtifact.wls` | Independently validates the built archive |
| `Scripts/BuildPaclet.wls` | Builds the documentation and `.paclet` archive |
| `Scripts/PacletBuildSupport.wl` | Builds both documentation languages and enforces artifact integrity |
| `.github/workflows/CI.yml` | Tests, builds, and orchestrates dev and stable publication |
| `.github/AUTOMATION.md` | Documents the checked-in repository automation contract |
| `.github/scripts/check-repository-config.sh` | Runs the local and CI repository-configuration gate |
| `.github/scripts/validate-repository-config.rb` | Validates settings, rulesets, Dependabot, and workflow policy |
| `.github/scripts/publish-paclet.sh` | Implements GitHub Release publication |
| `.github/tests/publish-paclet/` | Exercises release publication and interruption recovery with a local `gh` mock |
| `.github/dependabot.yml` | Maintains immutable GitHub Action pins |
| `.github/repository-settings/*.json` | Reproducible Actions and environment API payloads |
| `.github/rulesets/protect-main.json` | Importable main-branch history protection |
| `.github/rulesets/protect-version-tags.json` | Importable protection for stable version tags |
| `dist/` | Local `.paclet` build artifacts; not source |

The package uses Wolfram 15.0 Structured Package Format. Declare public
symbols with `PackageExported`; all implementation helpers must remain file
private.

## Running Tests

Run the Wolfram Language suite from the repository root:

```bash
wolframscript -file Tests/RunTests.wls
```

This suite checks package loading, the one-symbol API, output-form behavior,
evaluation and holding semantics, rendering rules, explicit rejection paths,
and structural parity of the bilingual documentation. Passing structural
checks does not establish translation accuracy; perform the human audit
required above as well.

Then run the cross-language validation:

```bash
wolframscript -file Tests/JuliaValidation.wls |
  julia --startup-file=no --check-bounds=yes Tests/JuliaValidation.jl
```

The Wolfram script writes actual renderer output to standard output. The Julia
driver reads that stream, verifies that every result parses completely, and
evaluates the cases whose values can be compared safely. It also executes the
cases that must fail at a documented runtime boundary. The syntax, value, and
error-source counts are explicit contract constants; update a count only with
its matching generated case and assertions. The Julia driver does not discover
or start Wolfram and has no operating-system-specific paths. It can also read a
previously generated file by accepting that path as its only argument.

Run both commands before opening a pull request or pushing directly to `main`.
The checked-in GitHub Actions workflow repeats both paths with Wolfram Engine
15.0.0 across Julia's `lts` and `latest` channels for pushes to `main`,
same-repository pull requests, merge-queue groups, strict version tags, and
manual runs. The `latest` channel uses setup-julia's `'1'` selector for the
latest stable Julia 1.x release. Wolfram commands run in the private, fully
licensed runtime managed by `.github/scripts/wolfram-runtime.sh`. Its unlimited
instance concurrency allows the two Julia matrix legs to run simultaneously on
independent runners. Fork pull requests cannot receive its image and Docker Hub
secrets, so their `CI summary` fails explicitly until a maintainer retests the
commit from a branch in the base repository.

The secret-free `Repository config` job is also a required prerequisite. It
pins actionlint by version and archive SHA-256, checks every workflow shell
script, validates the checked-in settings and rulesets exactly, and runs the
release publisher's local mock suite. Run the same gate on Linux amd64 with:

```bash
bash .github/scripts/check-repository-config.sh
```

When changing behavior:

- Add a focused `VerificationTest` with a unique, descriptive `TestID` to
  `Tests/JuliaForm.wlt`.
- Add emitted source to `Tests/JuliaValidation.wls` when Julia parsing is part
  of the contract.
- Add a value assertion to `Tests/JuliaValidation.jl` when the result can be
  evaluated without relying on definitions outside Julia Base.
- Cover both successful output and nearby unsupported cases when a semantic
  boundary is easy to cross accidentally.
- Keep tests deterministic and independent of user initialization files.

## Implementation Style

- Follow the existing Wolfram Language style: four-space indentation,
  descriptive lower-camel-case private helpers, and `$`-prefixed package
  constants.
- Keep `Kernel/init.wl` limited to package initialization. Put rendering logic
  in `Kernel/JuliaForm.wl`.
- Preserve held structure with `HoldComplete` and explicit held wrappers.
  Audit every new helper for accidental evaluation.
- Renderer branches return `{source, precedence}`. Assign the correct
  precedence and use the existing parenthesization helpers rather than
  concatenating nested expressions blindly.
- Reuse `juliaString` and identifier helpers for escaping. Generated source
  must remain safe for backslashes, quotes, control characters, `$`, Julia
  keywords, and nonstandard Wolfram contexts.
- Use `failUnsupported` for unsafe translations and make the diagnostic name
  the unsupported construct or semantic category clearly.
- Keep the Paclet dependency-free unless a new dependency is essential to the
  renderer and has been discussed explicitly.
- Update the canonical English README and symbol page first whenever the public
  contract, supported mapping table, documented limitation, tool requirement,
  or validation baseline changes; then audit and synchronize both Simplified
  Chinese translations in the same change.

## Pull Request Checklist

Before requesting review, confirm that:

- The change preserves the one-symbol public API unless an API expansion was
  explicitly agreed upon.
- Wolfram evaluation and held-expression behavior were considered separately.
- Julia precedence, scalar versus array behavior, and type semantics were
  checked for every new mapping.
- The Wolfram Language suite and cross-language validation both pass.
- The clean Paclet build and independent artifact validator both pass.
- `PacletInfo.wl` and the canonical English README are updated when
  compatibility or user-visible behavior changes.
- The canonical English `JuliaForm` symbol page is updated when the public
  contract, examples, supported mappings, or limitations change.
- Every changed English documentation file has a complete, technically
  faithful update in its paired Simplified Chinese translation.
- Heading structure, code examples, commands, links, identifiers, versions,
  requirements, and limitations have been compared across each changed pair.
- The documentation parity checks pass, and the Chinese wording has also
  received a human translation review.
- Generated `.paclet` archives are not included in a normal source change.

## Building and Releasing

Normal contributions should not add files under `dist/`; `.paclet` archives
are ignored build products. Build the same archive used by CI from the
repository root:

```bash
wolframscript -file Scripts/BuildPaclet.wls
```

The script resolves the repository root from its own location and writes the
archive to a freshly cleared `dist/`, so it does not depend on the caller's
absolute path or stale output. It explicitly builds the English and Simplified
Chinese notebooks and all three index families, packages the MIT license, and
then validates the exact Paclet contract, manifest hashes, indexes, Kernel file
set, and full size/SHA-256 inventory. Run the independent gate after the build;
it also exercises seven fail-closed artifact corruptions:

```bash
wolframscript -file Tests/ValidatePacletArtifact.wls
```

Every successful CI test run uploads the archive as a short-lived workflow
artifact. A push to `main` additionally sends that tested artifact through the
GitHub `dev` environment and updates the rolling prerelease at tag `dev`. The
publisher uploads a commit-unique asset, downloads it to verify SHA-256, moves
the tag only after that check, and removes stale assets last, so an interrupted
run is recoverable. The publish jobs are the only jobs with release write
permissions; pull requests, merge-queue groups, and manual runs never publish.
Restrict `dev` to `main` and `release` to `v*.*.*` tags in their environment
deployment policies.

Import `.github/rulesets/protect-main.json` and
`.github/rulesets/protect-version-tags.json` from repository `Settings` →
`Rules` → `Rulesets`. Keep both active without bypass actors. The main rule
allows direct fast-forward pushes while blocking branch deletion and history
rewrites. CI validates each accepted main-branch commit before the dev
publisher can update the rolling prerelease. The tag rule allows new `v*` tags
but blocks every update and deletion after creation, while leaving the rolling
`dev` tag mutable. Do not enable repository-wide release immutability, because
that setting would also lock the dev prerelease.

The rolling `dev` prerelease is not a stable versioned release. To cut a stable
release:

1. Bump `"Version"` in `PacletInfo.wl` according to semantic versioning.
2. Update the canonical English README and native symbol page when supported
   behavior or the validation baseline has changed, then audit and synchronize
   their Simplified Chinese translations.
3. Run both complete test paths in a clean checkout.
4. Build the `.paclet` archive and confirm that its filename, embedded
   metadata, and contents all use the new version.
5. Create and push a matching `vMAJOR.MINOR.PATCH` tag; do not commit the
   archive as source:

   ```bash
   git tag v0.2.0
   git push origin refs/tags/v0.2.0
   ```

After both Julia matrix legs pass, CI creates the stable GitHub Release and
attaches the tested archive, downloads it again to verify SHA-256, and only then
publishes it. The tag and Paclet versions must match exactly. CI may resume a
byte-identical draft but refuses a mismatched same-name asset or any change to
an already published stable Release. If a final publish response was lost, a
rerun may succeed read-only only after the canonical metadata, sole asset, and
remote SHA-256 all match. Never move, delete, or reuse a published version tag;
release a new patch version when a correction is required.

## Commit Message Convention

### Format

```text
<scope>(<target>): <subject>

<body>

<footer>
```

- All lines must not exceed 72 characters.
- All commit messages are written in English.

### Subject

- Must not exceed 50 characters.
- Use imperative mood (for example, `add`, not `added` or `adding`).
- Do not end with a period.
- Start with a lowercase letter unless the first word is a proper noun.

### Scope and Target

The scope identifies the part of the repository affected by the change.

| Scope | Meaning | Target example |
|-------|---------|----------------|
| `kernel` | SPF loader or renderer implementation | `precedence`, `indexing` |
| `test` | Wolfram or Julia validation tests | `rendering`, `unsupported` |
| `docs` | User and contributor documentation | `readme`, `contributing` |
| `paclet` | Paclet metadata and packaging | `metadata`, `build` |
| `ci` | Automated validation workflows | `tests`, `setup` |
| `release` | Version bump and release publication | `v0.2.0` |
| `repo` | Repository housekeeping | `gitignore`, `license` |

- `target` is the affected symbol, renderer area, file, or component, without
  a path prefix or file extension.
- Prefer a semantic target such as `indexing` or `held-evaluation` over an
  internal helper name when several helpers implement one behavior.
- When a commit affects multiple scopes equally, join them with `&` and use a
  single target that identifies the primary behavior. For example,
  `kernel&test(indexing)` describes an implementation change whose regression
  tests are equally central. Do not use `&` for incidental effects such as a
  small README clarification accompanying a renderer change.
- For the `release` scope, `target` is the new version tag.

### Body

- Separate it from the subject with one blank line.
- Use imperative mood.
- Explain why the change is needed, not merely what files changed.
- Keep every line within 72 characters.
- Use unordered lists (`-`) when enumerating distinct reasons or constraints.

### Footer

- AI-assisted commits must include an `Assisted-by` trailer as described
  below.
- Purely human commits require no footer trailer.
- Do not use `Co-authored-by` for AI attribution; use `Assisted-by` only.

### Subject Verbs

| Scenario | Recommended verbs | Example |
|----------|-------------------|---------|
| New mapping | `add`, `implement`, `introduce` | `kernel(functions): add logarithm mapping` |
| Remove behavior | `remove`, `delete` | `kernel(functions): remove unsafe mapping` |
| Bug fix | `fix`, `correct` | `kernel(precedence): fix nested powers` |
| Refine behavior | `update`, `revise`, `refine` | `kernel(indexing): refine span endpoints` |
| Tests | `add`, `cover`, `extend` | `test(unsupported): cover held list calls` |
| Documentation | `document`, `clarify` | `docs(readme): clarify Pair semantics` |
| Refactor | `refactor`, `rename`, `reorganize` | `kernel(strings): centralize escaping` |
| Packaging | `update`, `harden` | `paclet(metadata): raise Wolfram minimum` |
| Release | `bump`, `release` | `release(v0.2.0): bump minor for mappings` |
| CI or tooling | `add`, `update`, `harden` | `ci(tests): add cross-language validation` |

### AI Attribution

This policy follows the principles in the
[Linux Kernel AI Coding Assistants](https://docs.kernel.org/process/coding-assistants.html)
guidelines.

#### Format

```text
Assisted-by: AGENT_NAME:MODEL_NAME
```

#### Rules

- AI tools must not add `Signed-off-by` tags. Only humans can certify the
  Developer Certificate of Origin.
- The human committer must review all AI-generated content and take full
  responsibility for the contribution.
- When multiple AI tools assisted, use one `Assisted-by` line per tool.
- Do not use `Co-authored-by` for AI attribution.

#### Canonical Agent Names

`AGENT_NAME` must exactly match one of these entries:

| AGENT_NAME | Description |
|------------|-------------|
| `ClaudeCode` | Anthropic Claude |
| `GitHub-Copilot` | GitHub Copilot |
| `OpenCode` | OpenCode CLI |
| `Codex` | OpenAI Codex |

To add a new agent, append a row to this table in `CONTRIBUTING.md`.

#### Canonical Model Names

`MODEL_NAME` should be lowercase and may include version numbers or
descriptors that identify the model precisely, such as
`gemini-3.1-pro-preview`, `glm-5.1`, or `claude-opus-4.6`.

#### Examples

```text
kernel&test(precedence): preserve nested powers

- Julia parses chained powers right-associatively, so the renderer must
  preserve a Wolfram expression whose stored tree associates differently
- Regression coverage must compare emitted source as well as its Julia value

Assisted-by: ClaudeCode:claude-opus-4.6
```

```text
docs(readme): explain held list rejection

- Held list arithmetic can look like valid Julia matrix arithmetic while
  changing Wolfram elementwise semantics
- Users need an explicit rejection boundary before relying on generated code

Assisted-by: GitHub-Copilot:claude-opus-4.8
```

```text
kernel&test(indexing): preserve first-axis lookup

- A single Wolfram index selects along the first dimension, while direct
  Julia indexing would flatten arrays with more than one dimension
- The generated wrapper and its Julia value both need regression coverage

Assisted-by: Codex:gpt-5.5
```
