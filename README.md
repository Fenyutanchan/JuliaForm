# JuliaForm

**English** | [简体中文](README_zh-CN.md)

> [!NOTE]
> This file is the canonical project README. Documentation changes must update
> the English source first and then audit and synchronize the Simplified Chinese
> translation in the same change. If the two versions are ambiguous or conflict,
> the English version prevails.

`JuliaForm` is a paclet for Wolfram Language 15.0+ that renders Wolfram
expressions as deterministic, single-line UTF-8 Julia source code. It exports
one public symbol, `JuliaForm`, and its generated output is syntax- and
evaluation-tested with Julia's LTS and latest stable releases.

> [!IMPORTANT]
> `JuliaForm` is an expression renderer, not a complete Wolfram Language-to-Julia
> transpiler. It handles numbers, scalar expressions, common functions, lists,
> rules, associations, conditionals, and indexing. It explicitly rejects
> assignments, patterns, scoping, loops, and other program structures instead of
> emitting plausible-looking code with unreliable semantics.

## Documentation

- This README: installation, quick start, mapping rules, boundaries, and testing.
- [JuliaForm symbol reference](Documentation/English/ReferencePages/Symbols/JuliaForm.nb):
  the canonical native Wolfram documentation page, available from the
  Documentation Center or by selecting `JuliaForm` and pressing F1 after
  installing the paclet.
- [Simplified Chinese symbol reference](Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb):
  the rigorous translation of the English symbol page.
- [CONTRIBUTING.md](CONTRIBUTING.md): the canonical design constraints,
  bilingual documentation workflow, development, testing, and contribution
  rules.
- [CONTRIBUTING_zh-CN.md](CONTRIBUTING_zh-CN.md): the rigorous Simplified
  Chinese translation of the contribution guide.

## Requirements

| Purpose | Requirement |
|---|---|
| Load the paclet and generate Julia source | Wolfram Language 15.0+ with `PacletTools` |
| Execute the generated source | A Julia environment that provides the features used by the output |
| Reproduce the full cross-language validation matrix | Julia LTS and latest stable releases |
| Run tests and build the paclet | `wolframscript` |

Julia is not a runtime dependency of the paclet: generating source code does
not require starting Julia. CI tracks Julia's moving LTS and latest stable
channels instead of pinning one patch release.

`wolframscript` must also be able to locate the Wolfram kernel. If it reports
that the `WolframKernel` location cannot be determined, run
`wolframscript -configure` or explicitly set the installation path in the
current shell:

```sh
export WolframKernel=/absolute/path/to/WolframKernel
```

## Installation and Loading

### Install a built paclet

Replace the path with the actual `.paclet` file:

```wl
PacletInstall["/absolute/path/to/JuliaForm-0.1.0.paclet"];
Needs["JuliaForm`"];
```

After installation, subsequent Wolfram sessions need only:

```wl
Needs["JuliaForm`"];
```

### Load a development checkout

```wl
Needs["PacletTools`"];
PacletDirectoryLoad["/absolute/path/to/JuliaForm"];
Needs["JuliaForm`"];
```

After changing `Kernel/init.wl`, package initialization, or output-form
registration, validate in a fresh kernel so that directory-loading state from
an older session cannot mask a problem.

## Quick Start

Like `CForm` and `FortranForm`, `JuliaForm` is an output form. When evaluated
directly, it displays an expression in Julia syntax:

```wl
JuliaForm[Sin[x]^2 + Cos[x]^2]
(* cos(x) ^ 2 + sin(x) ^ 2 *)
```

Use either of the following forms when ordinary copyable text is required:

```wl
ToString[JuliaForm[a/(b + c)], OutputForm]
(* "a / (b + c)" *)

ToString[a/(b + c), JuliaForm]
(* "a / (b + c)" *)
```

Matrices and associations produce native Julia constructs:

```wl
ToString[JuliaForm[{{1, 2}, {3, 4}}], OutputForm]
(* "[1 2; 3 4]" *)

ToString[JuliaForm[<|"x" -> 1, "y" -> {2, 3}|>], OutputForm]
(* "Dict(\"x\" => 1, \"y\" => [2, 3])" *)
```

## API Contract

| Call | Result |
|---|---|
| `JuliaForm[expr]` | Stores an output-form wrapper and displays `expr` as a Julia expression |
| `ToString[JuliaForm[expr], OutputForm]` | Returns the Julia source string |
| `ToString[expr, JuliaForm]` | Returns the same source string as a compatibility form |

`JuliaForm` accepts exactly one argument and has no options. Output is fixed as
deterministic, single-line UTF-8 text, so the compatibility form
`ToString[expr, JuliaForm]` does not implement the page width, character
encoding, or other options of `ToString`. For an unsupported construct, the
function emits `JuliaForm::unsupported` and returns `$Failed`.

Top-level `JuliaForm[expr]` is registered in `$OutputForms`, so its interactive
display form is not stored in `Out`. An explicit assignment still stores the
wrapper, just as it does with `CForm`:

```wl
rendered = JuliaForm[x^2];
Head[rendered]
(* JuliaForm *)
```

If downstream code needs only text, call `ToString` immediately at that
boundary.

## Evaluation and `HoldForm`

`JuliaForm` first follows ordinary Wolfram Language evaluation semantics. For
example, standardization, arithmetic simplification, and `Listable` threading
occur before rendering.

Use `HoldForm` when the arithmetic structure of an input expression must be
preserved:

```wl
ToString[JuliaForm[HoldForm[(a + b) c]], OutputForm]
(* "(a + b) * c" *)

ToString[JuliaForm[HoldForm[a - (b + c)]], OutputForm]
(* "a - (b + c)" *)
```

`HoldForm` preserves the structure of one expression; it does not turn
`JuliaForm` into a general program serializer. Assignments, patterns, scoping,
loops, and similar structures are rejected even inside `HoldForm`. Conversion
also fails when `HoldForm` preserves a literal-list call that Wolfram Language
would normally thread, such as `HoldForm[Sin[{1, 2}]]`, because rendering it as
a Julia array call would change its semantics.

## Supported Mappings

### Numbers, constants, and strings

| Wolfram Language | Julia | Notes |
|---|---|---|
| `42` | `42` | Integers in the 64-bit range use literals |
| `2^100` | `big"1267650600228229401496703205376"` | Large integers preserve exactness |
| `1/3` | `1 // 3` | Exact rational number |
| `1.25` | `1.25` | Machine real |
| ``1.25`30`` | `BigFloat("1.25"; precision = 100)` | Explicit binary precision |
| `3 + 4 I` | `Complex(3, 4)` | Real and imaginary components retain their numeric types |
| `Pi`, `E`, `I` | `pi`, `ℯ`, `im` | Julia mathematical constants |
| `Infinity`, `-Infinity` | `Inf`, `-Inf` | Real infinities |
| `Indeterminate` | `NaN` | Not a number |
| `True`, `False`, `Null` | `true`, `false`, `nothing` | Basic atoms |

`EulerGamma`, `GoldenRatio`, and `Catalan` map to
`Base.MathConstants.eulergamma`, `Base.MathConstants.golden`, and
`Base.MathConstants.catalan`, respectively. Strings escape backslashes,
quotation marks, control characters, and the Julia interpolation character
`$`.

### Arithmetic, comparisons, and conditionals

| Wolfram Language | Julia |
|---|---|
| `Plus`, `Times`, `Power` | `+`, `*`, `^`, with parentheses inserted for Julia precedence |
| Division forms | `/`; exact `Rational` values continue to use `//` |
| `<`, `<=`, `>`, `>=`, `==`, `!=` | Corresponding Julia comparison operators |
| `SameQ`, `UnsameQ` | Strict comparisons combining `typeof` and `isequal` |
| `And`, `Or`, `Not` | `&&`, `||`, `!` |
| `If[c, t, f]` | `c ? t : f` |
| `Piecewise[...]` | Nested Julia ternary expressions |

`SameQ` and `UnsameQ` are not rewritten as plain `==` and `!=` because strict
Wolfram identity includes type differences. Their runtime comparator recurses
through arrays, pairs, and tuples, treats same-typed floating and complex
signed zero as Wolfram does, and rejects Julia dictionaries because their
iteration order cannot recover Association identity. Literal-list comparisons
are rejected before Julia element-type promotion can change a result.

Every ordinary multi-operand comparison first evaluates and binds every
operand exactly once, before any Julia chain can short-circuit. Ordering is
accepted only for non-Boolean real scalars. Equality and inequality reject
cases where Julia would silently invent a Boolean that Wolfram would not,
including dictionaries, `NaN`/`Indeterminate`, `missing`/`Missing`, and mixed
Boolean or `nothing`/`Null` structures.

### Functions

Common numerical functions are rewritten to Julia names:

- trigonometric, inverse trigonometric, hyperbolic, and inverse hyperbolic
  functions, such as `Sin` → `sin`, `ArcSin` → `asin`, `Sinh` → `sinh`, and
  `ArcSinh` → `asinh`;
- `Exp`, `Sqrt`, `Log`, `Abs`, `Sign`, `Min`, and `Max`;
- `Mod`, `GCD`, `LCM`, `Factorial`, and `Binomial`;
- `Conjugate` → `conj`, `Re` → `real`, `Im` → `imag`, and `Arg` → `angle`;
- `Inverse` → `inv`, `Det` → `det`, and `Tr` → `tr`.

Mapped functions accept only the arities for which the Julia call is known to
match. For example, two-argument `Mod` is supported, while the three-argument
Wolfram form is rejected. Held `Min[]`, `Max[]`, and `GCD[]` preserve their
degenerate Wolfram values as `Inf`, `-Inf`, and `0`.

The following mappings account for easy-to-miss semantic differences between
the two languages:

| Wolfram Language | Julia | Reason |
|---|---|---|
| `ArcTan[x, y]` | `atan(y, x)` | The two-argument order is reversed |
| `Sinc[x]` | `sinc(x / pi)` | Julia uses the normalized definition of `sinc` |
| `Quotient[x, y]` | `fld(x, y)` | This matches a quotient rounded toward negative infinity |

Names such as `inv`, `det`, and `tr` require Julia's `LinearAlgebra` standard
library:

```julia
using LinearAlgebra
```

An unknown symbolic head is emitted as a Julia function call. For example,
`BesselJ[0, x]` produces `BesselJ(0, x)`, and the Julia environment must provide
that definition. Type-sensitive operations without a universal equivalent,
including `Total`, `Length`, `Reverse`, `Transpose`, `Norm`, and
`Eigenvectors`, are not renamed speculatively. `Eigenvalues` is explicitly
rejected: Julia's `eigvals` does not preserve Wolfram's ordering contract, and
its partial-spectrum forms do not share Wolfram semantics.

### Lists, rules, associations, and symbols

| Wolfram Language | Julia |
|---|---|
| `{a, b}` | `[a, b]` |
| `{{a, b}, {c, d}}` | `[a b; c d]` |
| Ragged two-dimensional list | Julia vector of vectors |
| `x -> y` | `x => y` |
| `<|x -> y|>` | `Dict(x => y)` |
| `f[x, y]` | `f(x, y)` |

`Rule` maps to a Julia `Pair`, not to a Wolfram rewrite rule. Symbols outside
the <code>Global`</code> and <code>System`</code> contexts use Julia
`var"…"` identifiers so that distinct Wolfram contexts cannot silently
collide. Julia keywords and nonstandard identifiers use the same mechanism for
safe output.

### `Part` and array semantics

Wolfram and Julia both normally use 1 as their first index, but their
single-index matrix semantics differ: Wolfram's `m[[2]]` selects the second
slice of the first dimension, whereas Julia's `m[2]` uses linear indexing.
`JuliaForm` therefore emits a self-contained local dispatcher that evaluates
the indexed expression and every selector once, applies selectors by Wolfram
dimension, and fills omitted trailing array axes.

```wl
ToString[JuliaForm[HoldForm[v[[2 ;; -1]]]], OutputForm]
```

The dispatcher supports `All`, negative ordinal positions, `Span`, index lists,
and `Key`. Positive and negative positions are interpreted ordinally even for a
Julia array with custom axes. It maps those ordinals to actual axis labels and
assembles selections through scalar `getindex`, so custom arrays do not need a
`similar` implementation. Regular multidimensional arrays use their axes;
vectors and ragged nested arrays apply remaining selectors recursively. `All`
at the start and end of a `Span` means the first and last ordinal position,
respectively. Adjacent reversed endpoints produce Wolfram's valid empty
selection; a step that points farther away fails explicitly.

```wl
ToString[JuliaForm[HoldForm[m[[-1, All]]]], OutputForm]
```

A literal Wolfram `Association` is temporarily represented by its ordered rule
sequence while `Part` is evaluated, so positional, `All`, `Span`, list, and
`Key` selectors retain Wolfram ordering before the result is materialized as a
Julia `Dict`. Strict duplicate and signed-zero keys keep Wolfram's last-value
rule. Materialization fails if Julia would merge distinct Wolfram keys, such as
`1` and `1.`, and container-valued keys are rejected because Julia cannot
represent their semantics reliably. An arbitrary Julia `AbstractDict` has no
equivalent ordering guarantee, so only unambiguous `Key[...]` lookup is
accepted; positional selection fails explicitly. A missing key maps to Julia
`missing` and propagates through remaining selectors.

Operator output for `Plus`, `Times`, and `Power` has scalar semantics. Wolfram
Language normally threads explicit lists in ordinary calls before rendering.
If a held expression exposes literal-list arithmetic, conversion fails instead
of misrepresenting elementwise operations as Julia matrix operations.

## Explicitly Unsupported Constructs

The first release deliberately rejects the following categories:

- `ComplexInfinity` and `DirectedInfinity` with a non-real direction;
- rank-three and higher regular tensors, `SparseArray`, `Root`, and `Quantity`;
- `RuleDelayed` and `Association` values containing delayed or malformed
  rules;
- assignments and updates, including `Set`, `SetDelayed`, `AddTo`, and
  increment or decrement operations;
- patterns, pure functions, scoping, and evaluation-control structures other
  than `HoldForm`;
- procedural structures such as `CompoundExpression`, `Return`,
  `Throw`/`Catch`, `Do`, `While`, `For`, `Table`, `Switch`, `Which`, and
  `Scan`;
- held arithmetic over literal lists, held `SameQ`/`UnsameQ`, and held
  `Listable` function calls;
- ordinary comparisons over literal lists or runtime operands for which Julia
  would silently change Wolfram Boolean, missing-value, dictionary-order, or
  ordering semantics;
- `Eigenvalues`, whose Julia ordering and partial-spectrum contracts differ;
- index `0`, `UpTo`, a zero-step or non-adjacent wrong-direction `Span`, and
  `Part` without an index, plus positional or ambiguous-key `Part` on an
  arbitrary runtime `Dict` and container-valued Association keys.

`If` and `Piecewise` are expression-level conditionals and are explicitly
supported. The restrictions above apply to program structures that cannot be
safely represented as a single Julia expression.

## Repository Layout

This paclet uses the Wolfram 15.0 Structured Package Format (SPF):

```text
PacletInfo.wl
Kernel/
  init.wl
  JuliaForm.wl
Documentation/
  English/ReferencePages/Symbols/JuliaForm.nb
  ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb
Tests/
  JuliaForm.wlt
  JuliaValidation.wls
  JuliaValidation.jl
  RunTests.wls
  ValidatePacletArtifact.wls
Scripts/
  BuildPaclet.wls
  PacletBuildSupport.wl
LICENSE
README.md
README_zh-CN.md
CONTRIBUTING.md
CONTRIBUTING_zh-CN.md
```

`Kernel/init.wl` loads the implementation through `PackageInitialize`. The
implementation file declares only `PackageExported[JuliaForm]`; every other
symbol is file-private. `PacletInfo.wl` declares both the Kernel extension and a
multilingual Documentation extension so that the built artifact can index the
English and Simplified Chinese native symbol pages, plus an Asset extension for
the top-level MIT license.

## Testing

Run the Wolfram Language tests from the repository root:

```sh
wolframscript -file Tests/RunTests.wls
```

Then run the cross-language validation:

```sh
wolframscript -file Tests/JuliaValidation.wls |
  julia --startup-file=no --check-bounds=yes Tests/JuliaValidation.jl
```

The first suite covers the single public API, form contract, evaluation and
holding semantics, numbers, operator precedence, function differences,
strings, arrays, `Pair`, `Dict`, indexing, unknown-function fallback, rejection
paths, and structural parity of the bilingual documentation. Structural checks
do not replace the required human review of translation accuracy. The
cross-language validation first asks the Wolfram kernel to generate real source
code, then uses Julia's `Meta.parseall` to check complete syntax and evaluates
assertions for self-contained results. Its checked contract currently contains
31 syntax-only sources, 122 evaluated sources, and 47 sources that must parse
but raise a documented runtime rejection. The Julia driver locks all three
counts so a producer/consumer drift cannot silently skip assertions.

`JuliaValidation.jl` neither finds nor starts Wolfram and makes no assumption
about the operating system or installation path. The caller can choose a local
kernel, `wolframscript`, or a container. It reads generated results from
standard input by default and accepts one output-file path as its only
argument; use `-` to select standard input explicitly. Run it with Julia bounds
checking enabled when changing indexing code.

## Building the Paclet and Documentation

Run the unified build script from the repository root:

```sh
wolframscript -file Scripts/BuildPaclet.wls
```

The script determines the repository root from its own location, so it does not
depend on the caller's absolute path. The resulting archive is written to
`dist/`, which is cleared first so stale output cannot satisfy a build. The
build explicitly compiles both `English` and `ChineseSimplified` notebooks and
creates each language's `Index`, `SearchIndex`, and `SpellIndex` before
`PacletBuild` packages the Kernel, documentation, and `LICENSE` asset. It then
checks the exact Paclet extensions and Kernel file set, manifest paths and
SHA-256 hashes, required files and indexes, the unique archive, and an exact
size/SHA-256 inventory of every packaged file except the inventory itself.
`Tests/ValidatePacletArtifact.wls` independently extracts and validates the
archive, then runs seven fault-injection regressions so extra, truncated,
escaping, malformed, or misnamed artifacts must fail closed. Ordinary source
changes should not commit a newly generated `.paclet` archive; see
[CONTRIBUTING.md](CONTRIBUTING.md) for release steps and versioning rules.

## License

JuliaForm is distributed under the [MIT License](LICENSE). The license file is
also included in every validated `.paclet` archive.

## GitHub Actions CI

On pushes to `main`, same-repository pull requests, merge-queue groups, strict
`vMAJOR.MINOR.PATCH` tags, and manual runs, `.github/workflows/CI.yml` uses
Wolfram Engine 15.0.0 and a two-entry Julia matrix covering `lts` and `latest`.
Ordinary feature-branch pushes are not a second trigger, so an open pull
request is not billed twice. The `latest` channel maps to setup-julia's `'1'`
selector for the latest stable Julia 1.x release. After both matrix legs pass,
the latest leg builds and independently validates the `.paclet`, then uploads
it as `JuliaForm-paclet` with seven-day retention. A secret-free `Repository
config` job also pins and runs actionlint, validates every checked-in policy,
and exercises the publisher with a local `gh` mock. The single `CI summary`
job requires both configuration and test gates. Only pull-request runs cancel
obsolete work; main and tag runs cannot be interrupted while approaching
publication.

All GitHub Actions use full commit SHA pins with human-readable version
comments, and the Wolfram container uses an image digest. Repository Actions
settings should require SHA pinning and allow only GitHub-owned actions plus
`julia-actions/setup-julia`; `.github/dependabot.yml` maintains these pins
weekly. The API payloads under `.github/repository-settings/` make these
settings and the environment policies reproducible. Test jobs have only
`contents: read`, while preflight and summary jobs receive no token permissions.

A push to `main` also starts an independent `publish-dev` job. This job sparsely
checks out only the release helper, downloads the artifact that just passed
validation, and updates a rolling prerelease through the GitHub environment
`dev`. It uploads a commit-unique asset before moving the mutable `dev` tag,
downloads that remote asset to verify SHA-256, then deletes stale Paclets last.
An interrupted run therefore leaves either the previous usable release or an
extra recoverable asset, and a rerun can resume without moving the tag to
unverified bytes. The prerelease is never marked as Latest. Only publish jobs
receive the required `contents: write` and `deployments: write` permissions.
Pull requests, merge-queue groups, and manual runs never publish.

A pushed tag matching `vMAJOR.MINOR.PATCH`, such as `v0.1.0`, starts the
independent `publish-release` job after both test legs pass. The tag version
must match the version embedded in the generated archive. The helper creates a
draft, attaches the tested Paclet, downloads it again to compare SHA-256, checks
that the draft has exactly the expected Paclet asset, and only then publishes
the stable GitHub Release. A rerun may resume a matching draft but refuses a
same-name asset with different bytes. It never changes a stable Release that
has already been published; after an ambiguous final API response, an exact
metadata, sole-asset, and SHA-256 match is accepted as a read-only no-op.

Create `dev` and `release` under repository `Settings` → `Environments` before
the first run. Restrict `dev` deployment to `main` and `release` deployment to
`v*.*.*` tags. If an environment does not already exist, GitHub creates it
without protection rules when the workflow first references it, which is not a
safe substitute for this configuration.

Import both `.github/rulesets/protect-main.json` and
`.github/rulesets/protect-version-tags.json` under repository `Settings` →
`Rules` → `Rulesets`. The main rule requires the up-to-date `CI summary` check
from the GitHub Actions App and blocks deletion and force pushes while allowing
initial branch creation. The tag rule permits initial creation but blocks every
subsequent update and deletion for tags beginning with `v`; it deliberately
does not match the mutable `dev` tag. Neither ruleset defines a bypass actor.

Repository-wide release immutability is intentionally not enabled because it
would also lock the rolling prerelease. Stable versions are instead immutable
by project policy: the tag ruleset prevents their refs from moving, and CI
refuses to overwrite an existing published Release. Corrections require a new
patch version.

Before the first run, also create an on-demand license entitlement in Wolfram
Language:

```wl
entitlement = CreateLicenseEntitlement[];
entitlement["EntitlementID"]
```

Store the returned value as the repository secret
`WOLFRAMSCRIPT_ENTITLEMENTID` under GitHub repository `Settings` →
`Secrets and variables` → `Actions`. This license consumes Wolfram Service
Credits; configure its validity, concurrent kernel count, and cost policy for
the account. See
[Wolfram's PacletCICD license documentation](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/PacletCICD/tutorial/LicenseEntitlementsAndRepositorySecrets.html)
for details.

GitHub does not expose repository secrets to pull requests from forks. Such a
pull request runs preflight but its `CI summary` deliberately fails instead of
reporting a false green check. A maintainer must retest the commit from a branch
in the base repository that can access the secret. Do not use
`pull_request_target` to execute pull-request code.
