# JuliaForm

[English](README.md) | **简体中文**

> [!NOTE]
> 本文件是规范英文文档 [README.md](README.md) 的简体中文严谨翻译。项目文档
> 先更新英文规范源，再在同一变更中核对并同步本翻译；如两者存在歧义，以英文
> 版本为准。

`JuliaForm` 是一个面向 Wolfram Language 15.0+ 的 Paclet，用来把 Wolfram
表达式渲染成确定性的、单行 UTF-8 Julia 源码。它只导出一个公共符号
`JuliaForm`，生成结果会在 Julia LTS 与最新稳定版上进行语法和求值验证。

> [!IMPORTANT]
> `JuliaForm` 是表达式渲染器，不是 Wolfram Language 到 Julia 的完整转译器。
> 它处理数值、标量表达式、常用函数、列表、规则、关联、条件表达式和索引；
> 对赋值、模式、作用域、循环等程序结构会明确报错，而不是生成貌似合法但语义
> 不可靠的代码。

## 文档入口

- 本 README：安装、快速开始、映射规则、边界与测试方法。
- [JuliaForm 英文符号参考](Documentation/English/ReferencePages/Symbols/JuliaForm.nb)：
  规范的 Wolfram 原生文档页；安装 Paclet 后可从文档中心打开，也可选中
  `JuliaForm` 后按 F1 打开。
- [简体中文符号参考](Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb)：
  英文符号页的严谨翻译。
- [CONTRIBUTING.md](CONTRIBUTING.md)：设计约束、双语文档流程、开发、测试和
  贡献规范的英文规范源。
- [CONTRIBUTING_zh-CN.md](CONTRIBUTING_zh-CN.md)：贡献指南的简体中文严谨
  翻译。

## 环境要求

| 用途 | 要求 |
|---|---|
| 加载和生成 Julia 源码 | Wolfram Language 15.0+，含 `PacletTools` |
| 执行生成的源码 | 与输出所用功能相匹配的 Julia 环境 |
| 复现完整跨语言验证矩阵 | Julia LTS 与最新稳定版 |
| 运行测试和构建 Paclet | `wolframscript` |

Julia 不是 Paclet 的运行时依赖：只生成源码时不需要启动 Julia。CI 跟随 Julia
持续更新的 LTS 与最新稳定版通道，不再固定到某个补丁版本。

`wolframscript` 还必须能定位 Wolfram 内核。若它提示无法确定
`WolframKernel` 位置，可先运行 `wolframscript -configure`，或在当前 shell 中
显式指定安装路径：

```sh
export WolframKernel=/absolute/path/to/WolframKernel
```

## 安装与加载

### 安装构建产物

把路径替换为实际的 `.paclet` 文件：

```wl
PacletInstall["/absolute/path/to/JuliaForm-0.1.0.paclet"];
Needs["JuliaForm`"];
```

安装后，后续 Wolfram 会话只需：

```wl
Needs["JuliaForm`"];
```

### 直接加载开发目录

```wl
Needs["PacletTools`"];
PacletDirectoryLoad["/absolute/path/to/JuliaForm"];
Needs["JuliaForm`"];
```

修改 `Kernel/init.wl`、包初始化或输出 Form 注册逻辑后，建议使用全新内核验证，
避免旧会话中的目录加载状态掩盖问题。

## 快速开始

与 `CForm` 和 `FortranForm` 一样，`JuliaForm` 是输出 Form。直接求值时，它
以 Julia 语法显示表达式：

```wl
JuliaForm[Sin[x]^2 + Cos[x]^2]
(* cos(x) ^ 2 + sin(x) ^ 2 *)
```

需要得到可复制的普通字符串时，使用以下任一形式：

```wl
ToString[JuliaForm[a/(b + c)], OutputForm]
(* "a / (b + c)" *)

ToString[a/(b + c), JuliaForm]
(* "a / (b + c)" *)
```

矩阵和关联会生成 Julia 原生构造：

```wl
ToString[JuliaForm[{{1, 2}, {3, 4}}], OutputForm]
(* "[1 2; 3 4]" *)

ToString[JuliaForm[<|"x" -> 1, "y" -> {2, 3}|>], OutputForm]
(* "Dict(\"x\" => 1, \"y\" => [2, 3])" *)
```

## API 契约

| 调用 | 结果 |
|---|---|
| `JuliaForm[expr]` | 保存一个输出 Form wrapper，并把 `expr` 显示为 Julia 表达式 |
| `ToString[JuliaForm[expr], OutputForm]` | 返回 Julia 源码字符串 |
| `ToString[expr, JuliaForm]` | 返回相同的源码字符串，作为兼容写法 |

`JuliaForm` 恰好接受一个参数，没有选项。生成结果固定为确定性的单行 UTF-8
文本，因此兼容形式 `ToString[expr, JuliaForm]` 不实现 `ToString` 的分页、字符
编码或其他选项。遇到不支持的结构时，函数发送 `JuliaForm::unsupported` 并返回
`$Failed`。

顶层 `JuliaForm[expr]` 已注册到 `$OutputForms`，所以交互式显示形式不会存入
`Out`。但是显式赋值仍会保存 wrapper，这一点与 `CForm` 相同：

```wl
rendered = JuliaForm[x^2];
Head[rendered]
(* JuliaForm *)
```

若后续代码只需要文本，应在边界处立即调用 `ToString`。

## 求值与 `HoldForm`

`JuliaForm` 首先遵循 Wolfram Language 的普通求值语义。例如，表达式会先完成
标准化、算术化简和 `Listable` 线程化，再被渲染。

需要保留一个输入表达式的算术结构时，使用 `HoldForm`：

```wl
ToString[JuliaForm[HoldForm[(a + b) c]], OutputForm]
(* "(a + b) * c" *)

ToString[JuliaForm[HoldForm[a - (b + c)]], OutputForm]
(* "a - (b + c)" *)
```

`HoldForm` 只用于保留单个表达式的结构，不会把 `JuliaForm` 变成通用程序
序列化器。赋值、模式、作用域、循环等结构即使放在 `HoldForm` 中也会被拒绝。
如果 `HoldForm` 保留了本应由 Wolfram Language 线程化的字面量列表调用，例如
`HoldForm[Sin[{1, 2}]]`，转换同样会失败，以免误写成不同的 Julia 数组语义。

## 支持的映射

### 数值、常量与字符串

| Wolfram Language | Julia | 说明 |
|---|---|---|
| `42` | `42` | 64 位范围内的整数使用字面量 |
| `2^100` | `big"1267650600228229401496703205376"` | 大整数保留精确性 |
| `1/3` | `1 // 3` | 精确有理数 |
| `1.25` | `1.25` | 机器实数 |
| ``1.25`30`` | `BigFloat("1.25"; precision = 100)` | 显式二进制精度 |
| `3 + 4 I` | `Complex(3, 4)` | 实部与虚部分别保留数值类型 |
| `Pi`, `E`, `I` | `pi`, `ℯ`, `im` | Julia 数学常量 |
| `Infinity`, `-Infinity` | `Inf`, `-Inf` | 实无穷 |
| `Indeterminate` | `NaN` | 非数值 |
| `True`, `False`, `Null` | `true`, `false`, `nothing` | 基本原子 |

`EulerGamma`、`GoldenRatio` 和 `Catalan` 分别映射到
`Base.MathConstants.eulergamma`、`Base.MathConstants.golden` 和
`Base.MathConstants.catalan`。字符串会转义反斜杠、引号、控制字符和 Julia
插值字符 `$`。

### 算术、比较与条件表达式

| Wolfram Language | Julia |
|---|---|
| `Plus`, `Times`, `Power` | `+`, `*`, `^`，并按 Julia 优先级补括号 |
| 除法形式 | `/`；精确 `Rational` 仍使用 `//` |
| `<`, `<=`, `>`, `>=`, `==`, `!=` | 对应的 Julia 比较运算符 |
| `SameQ`, `UnsameQ` | 结合 `typeof` 与 `isequal` 的严格比较 |
| `And`, `Or`, `Not` | `&&`, `||`, `!` |
| `If[c, t, f]` | `c ? t : f` |
| `Piecewise[...]` | 嵌套的 Julia 三元表达式 |

顶层精确有理数保持紧凑形式（`1 // 3`），但在更大的乘除链中会加括号。例如，
`FullSimplify[1 + 3/(2 x)]` 会渲染为 `1 + (3 // 2) / x`。这些括号让精确
有理数系数在视觉上更加明确，同时不会把它改成非精确的 `/` 算术。

`SameQ` 和 `UnsameQ` 不是简单改写为 `==`/`!=`，因为 Wolfram 的严格同一性
包含类型差异。其运行时比较器会递归处理数组、pair 和 tuple，按 Wolfram 语义
处理同类型浮点数与复数的 signed zero；Julia dictionary 无法恢复 Association
顺序，因此会被拒绝。字面量列表比较会在 Julia 元素类型提升改变结果之前拒绝。

所有普通多操作数比较都会先把每个操作数求值并绑定恰好一次，再执行可能短路的
Julia 比较链。排序只接受非布尔实数标量。相等与不等比较会拒绝 Julia 可能静默
生成错误布尔值的情况，包括 dictionary、`NaN`/`Indeterminate`、
`missing`/`Missing`，以及混合 Boolean 或 `nothing`/`Null` 的结构。

### 函数

常用数值函数会改写为 Julia 名称：

- 三角、反三角、双曲和反双曲函数，如 `Sin` → `sin`、`ArcSin` → `asin`、
  `Sinh` → `sinh`、`ArcSinh` → `asinh`；
- `Exp`、`Sqrt`、`Log`、`Abs`、`Sign`、`Min`、`Max`；
- `Mod`、`GCD`、`LCM`、`Factorial`、`Binomial`；
- `Conjugate` → `conj`、`Re` → `real`、`Im` → `imag`、`Arg` → `angle`；
- `Inverse` → `inv`、`Det` → `det`、`Tr` → `tr`。

映射函数只接受已经确认与 Julia 调用一致的参数个数。例如，双参数 `Mod` 受
支持，而 Wolfram 的三参数形式会被拒绝。held `Min[]`、`Max[]`、`GCD[]` 会
分别保留其 Wolfram 退化值 `Inf`、`-Inf`、`0`。

以下映射处理了两个语言之间容易忽略的语义差异：

| Wolfram Language | Julia | 原因 |
|---|---|---|
| `ArcTan[x, y]` | `atan(y, x)` | 两边的双参数顺序相反 |
| `Sinc[x]` | `sinc(x / pi)` | Julia 的 `sinc` 采用归一化定义 |
| `Quotient[x, y]` | `fld(x, y)` | 对应向负无穷取整的商 |

`inv`、`det`、`tr` 等名称需要 Julia 的 `LinearAlgebra` 标准库：

```julia
using LinearAlgebra
```

未知的符号头会按 Julia 函数调用输出，例如 `BesselJ[0, x]` 生成
`BesselJ(0, x)`；Julia 端必须自行提供该定义。类型敏感而且没有普遍等价关系的
`Total`、`Length`、`Reverse`、`Transpose`、`Norm`、`Eigenvectors` 等不会被
擅自改名。`Eigenvalues` 会被明确拒绝：Julia `eigvals` 不保留 Wolfram 的排序
契约，其部分谱形式也不具有相同语义。

### 列表、规则、关联与符号

| Wolfram Language | Julia |
|---|---|
| `{a, b}` | `[a, b]` |
| `{{a, b}, {c, d}}` | `[a b; c d]` |
| 不规则二维列表 | Julia 向量的向量 |
| `x -> y` | `x => y` |
| `<|x -> y|>` | `Dict(x => y)` |
| `f[x, y]` | `f(x, y)` |

`Rule` 映射到 Julia `Pair`，不是 Wolfram 重写规则。非
<code>Global`</code>/<code>System`</code> 上下文的符号使用 Julia 的
`var"…"` 标识符，避免不同 Wolfram 上下文静默
碰撞；Julia 关键字和非标准标识符也使用同一机制安全输出。

### `Part` 与数组语义

Wolfram 和 Julia 通常都以 1 为首个索引，但单索引矩阵语义不同：Wolfram 的
`m[[2]]` 选择第一维的第二个切片，而 Julia 的 `m[2]` 使用线性索引。因此，
`JuliaForm` 会生成一个自包含的局部 dispatcher：索引对象和每个选择器都只求值
一次，选择器按 Wolfram 维度应用，并自动补齐省略的数组尾轴。

```wl
ToString[JuliaForm[HoldForm[v[[2 ;; -1]]]], OutputForm]
```

该 dispatcher 支持 `All`、负序数位置、`Span`、索引列表和 `Key`。即使 Julia
数组使用自定义轴，正负位置仍按序数解释；这些序数会映射到真实轴标签，并通过
scalar `getindex` 组装选择结果，因此自定义数组不必实现 `similar`。规则多维
数组使用自身的轴；向量和不规则嵌套数组会递归应用剩余选择器。`Span` 起点和
终点处的 `All` 分别表示第一个和最后一个序数位置。相邻的反向端点产生 Wolfram
允许的空选择；步长若指向更远的反方向则明确失败。

```wl
ToString[JuliaForm[HoldForm[m[[-1, All]]]], OutputForm]
```

字面 Wolfram `Association` 在执行 `Part` 时会暂时按有序规则序列表示，因此
位置、`All`、`Span`、列表和 `Key` 选择都先保留 Wolfram 顺序，再把结果实体化
为 Julia `Dict`。严格重复键和 signed-zero 键遵循 Wolfram 的后值覆盖规则；若
Julia 会合并 Wolfram 中不同的键（如 `1` 与 `1.`），实体化会失败。容器值键也会
被拒绝，因为 Julia 无法可靠表示其语义。任意 Julia `AbstractDict` 没有等价的
顺序保证，所以只接受无歧义的 `Key[...]`；位置选择会明确失败。缺失键映射为
Julia `missing`，并在剩余选择器中传播。

`Plus`、`Times`、`Power` 的运算符输出以标量语义为准。普通调用中的显式列表
通常已由 Wolfram Language 完成线程化；如果 held 表达式暴露字面量列表算术，
转换会失败，而不会把逐元素运算误写成 Julia 矩阵运算。

## 明确不支持的结构

首版刻意拒绝以下类别：

- `ComplexInfinity` 和非实方向的 `DirectedInfinity`；
- 三阶及更高的规则张量、`SparseArray`、`Root`、`Quantity`；
- `RuleDelayed`，以及含延迟规则或畸形规则的 `Association`；
- 赋值和更新，包括 `Set`、`SetDelayed`、`AddTo`、自增/自减等；
- 模式、纯函数、作用域，以及除 `HoldForm` 外的求值控制结构；
- `CompoundExpression`、`Return`、`Throw`/`Catch`、`Do`、`While`、`For`、
  `Table`、`Switch`、`Which`、`Scan` 等过程式结构；
- 字面量列表的 held 算术、held `SameQ`/`UnsameQ`，以及 held `Listable`
  函数调用；
- 字面量列表的普通比较，或 Julia 会静默改变 Wolfram 布尔值、缺失值、
  dictionary 顺序或排序语义的运行时比较操作数；
- `Eigenvalues`，因为 Julia 的排序和部分谱契约不同；
- `0`、`UpTo`、零步长或非相邻反向的 `Span`、没有索引的 `Part`，以及任意
  运行时 `Dict` 上的位置或歧义键 `Part`，以及容器值 Association 键。

其中 `If` 和 `Piecewise` 是表达式级条件，已明确支持；上面的限制针对无法安全
表示为单个 Julia 表达式的程序结构。

## 项目结构

本 Paclet 使用 Wolfram 15.0 的 Structured Package Format（SPF）：

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

`Kernel/init.wl` 通过 `PackageInitialize` 加载实现；实现文件只声明
`PackageExported[JuliaForm]`，其余符号均为文件私有。`PacletInfo.wl` 同时声明
Kernel 扩展和多语言 Documentation 扩展，使构建产物可以索引英文与简体中文
原生符号页，并通过 Asset 扩展包含顶层 MIT 许可证。

## 测试

从项目根目录运行 Wolfram Language 测试：

```sh
wolframscript -file Tests/RunTests.wls
```

再运行跨语言验证：

```sh
wolframscript -file Tests/JuliaValidation.wls |
  julia --startup-file=no --check-bounds=yes Tests/JuliaValidation.jl
```

第一组测试覆盖唯一公共 API、Form 契约、求值和 holding 语义、数值、运算符
优先级、函数差异、字符串、数组、`Pair`、`Dict`、索引、未知函数回退、拒绝
路径和双语文档的结构一致性。结构检查不能取代对翻译准确性的必要人工审校。
跨语言验证先让 Wolfram 内核生成真实源码，再由 Julia 的 `Meta.parseall` 检查
完整语法，并对可独立求值的结果执行断言。当前锁定契约包含 31 个仅语法源码、
122 个求值源码和 47 个必须成功解析但触发已记录运行时拒绝的源码。Julia 驱动会
锁定三类数量，避免生产端与消费端偏移后静默漏掉断言。

`JuliaValidation.jl` 本身不查找或启动 Wolfram，也不假设操作系统或安装路径；
调用者可以自行选择本地内核、`wolframscript` 或容器。它默认从标准输入读取生成
结果，也接受一个输出文件路径作为唯一参数；使用 `-` 可显式选择标准输入。修改
索引代码时，应启用 Julia bounds checking 运行它。

## 构建 Paclet 与文档

从项目根目录运行统一构建脚本：

```sh
wolframscript -file Scripts/BuildPaclet.wls
```

脚本从自身位置确定仓库根目录，因此不依赖调用者的绝对路径；生成的归档位于
`dist/`；该目录会先被清空，避免陈旧输出让构建假成功。构建会显式编译
`English` 与 `ChineseSimplified` notebook，并为每种语言生成 `Index`、
`SearchIndex`、`SpellIndex`，再由 `PacletBuild` 打包 Kernel、文档和 `LICENSE`
asset。随后还会检查精确 Paclet extensions 与 Kernel 文件集、manifest 路径及
SHA-256、必需文件和索引、唯一归档，以及除 inventory 自身外每个打包文件的精确
大小/SHA-256 inventory。`Tests/ValidatePacletArtifact.wls` 会独立解包并重复门禁，
再执行 7 个故障注入回归，要求额外、截断、逃逸、畸形或错误命名的产物全部
fail-closed。普通源码变更不应提交新生成的 `.paclet` 归档；发布步骤和版本规则见
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

JuliaForm 采用 [MIT License](LICENSE) 发布。每个通过验证的 `.paclet` 归档中也
会包含该许可证文件。

## GitHub Actions CI

`.github/workflows/CI.yml` 会在向 `main` push、同仓库 pull request、merge queue
group、严格的 `vMAJOR.MINOR.PATCH` tag 和手动触发时，使用仓库的私有、完整授权
Wolfram 15.0.0 运行时与包含 `lts`、`latest` 的双项 Julia 矩阵运行测试。普通功能
分支 push 不是第二个触发源，因此已打开的 pull request 不会重复计费。`latest`
通道映射到 setup-julia 的 `'1'` 选择器，即最新稳定的 Julia 1.x。两个矩阵项都
使用支持无限并发实例的私有运行时，因此不再串行限制两个矩阵项；它们可以同时
占用各自独立的 runner。两个矩阵项都通过后，latest 项会构建并独立验证
`.paclet`，再以 `JuliaForm-paclet` 名称保留 7 天。不读取 secret 的
`Repository config` 作业还会固定并运行 actionlint、验证每份受版本控制的策略，
并用本地 `gh` mock 测试发布器。唯一的 `CI summary` 作业要求配置与测试门禁都
成功。只有 pull-request 运行会取消过时工作；main 和 tag 运行在接近发布时不会
被中断。

所有 GitHub Action 都固定到完整 commit SHA，并保留便于阅读的版本注释。应尽量
把 `WOLFRAM_RUNTIME_IMAGE` 设为不可变的 digest reference；CI 还会在测试前要求
第一个经原生 entrypoint 初始化的容器准确报告 Wolfram 15.0.0。仓库 Actions 设置
应强制 SHA pin，并且只允许 GitHub 自有 Action 与 `julia-actions/setup-julia`；
`.github/dependabot.yml` 每周维护这些 pin。`.github/repository-settings/` 下的 API
payload 使这些设置与 environment 策略可以复现。测试作业只有 `contents: read`，
preflight 与 summary 作业没有 token 权限。

`main` 分支的 push 还会启动独立的 `publish-dev` 作业。该作业只稀疏检出发布
辅助脚本，下载刚刚通过验证的 artifact，并通过 GitHub environment `dev` 更新
滚动 prerelease。它先上传 commit 唯一的资产，再移动可变 `dev` tag，最后才
重新下载远端资产并验证 SHA-256，最后才删除陈旧 Paclet。因此，中断只会留下
上一个可用 release 或一个可恢复的额外资产；重跑不会把 tag 移到未经验证的字节。
该 prerelease 永远不会标记为 Latest。只有发布作业具有所需的 `contents: write`
和 `deployments: write` 权限；pull request、merge queue group 和手动运行均不会
发布。

push 符合 `vMAJOR.MINOR.PATCH` 的 tag（例如 `v0.1.0`）后，两个测试项都通过
才会启动独立的 `publish-release` 作业。tag 版本必须与生成归档中嵌入的版本
一致。辅助脚本会先创建 draft、附加经过测试的 Paclet，最后发布稳定的 GitHub
Release；发布前会重新下载资产比较 SHA-256，并确认 draft 恰好含预期 Paclet。
重跑可以恢复字节一致的 draft，但同名而内容不同的资产会被拒绝；已经发布的
稳定 Release 永远不允许修改；若最终 API 响应不明确，只有 metadata、唯一资产
和 SHA-256 完全一致时，重跑才以只读 no-op 成功。

首次运行前应在仓库 `Settings` → `Environments` 中创建 `dev` 和 `release`。
限制 `dev` 只能从 `main` 部署，并限制 `release` 只能从 `v*.*.*` tag 部署。
若未预先创建，GitHub 会在工作流首次引用时创建没有保护规则的同名 environment，
这不能替代上述安全配置。

应在仓库 `Settings` → `Rules` → `Rulesets` 中同时导入
`.github/rulesets/protect-main.json` 和
`.github/rulesets/protect-version-tags.json`。main 规则允许直接快进 push，同时
阻止删除和强制 push。CI 会验证每个已经进入 main 的 commit，只有通过后
dev 发布器才会更新滚动预发布版本。tag 规则允许首次创建，但会阻止随后对以
`v` 开头的 tag 进行任何更新或删除；它有意不匹配可变的 `dev` tag。两份 ruleset 都不
定义 bypass actor。

本项目有意不启用仓库级 release immutability，因为它也会锁定滚动 prerelease。
稳定版本改由项目策略保证不可变：tag ruleset 阻止移动对应 ref，CI 则拒绝覆盖
已经发布的 Release。需要修正时必须发布新的补丁版本。

首次运行前，需要配置以下 repository Actions secrets：

| Secret | 必需值 |
| --- | --- |
| `WOLFRAM_RUNTIME_IMAGE` | 私有 Wolfram 15.0.0 镜像的完整 Docker reference；推荐使用 `namespace/repository@sha256:...` |
| `DOCKERHUB_USERNAME` | 有权拉取该镜像的 Docker Hub 账户 |
| `DOCKERHUB_TOKEN` | 该账户的只读 Docker Hub access token |

镜像必须提供可非交互运行的 Linux amd64 `wolframscript`、支持以 root 执行，并
使用一个先安装许可证或准备环境、再转交所给命令的 entrypoint。工作流有意不使用
`jobs.<job_id>.container`：GitHub 允许在 container credentials 中使用 secrets，
却不允许在
[`container.image`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability)
中使用。`.github/scripts/wolfram-runtime.sh` 因此改在 runner 上使用隔离的 Docker
认证目录，拉取 secret 指定的镜像，并只记录本地 image ID。每条 Wolfram 命令随后
都在一次性的 `docker run --rm` 容器中执行，保留镜像原生 entrypoint，并把
checkout 挂载到 `/workspace`。这样，entrypoint 安装的 mathpass 数据和导出的环境
变量都会传给 Wolfram 进程。Julia 验证从容器内重定向的文件读取 Wolfram 输出，
避免 entrypoint 日志污染生成源码流。无条件运行的清理步骤会删除任何中断残留的
容器、本地状态并登出。已经废弃的 `WOLFRAMSCRIPT_ENTITLEMENTID` secret 不再被
读取。

GitHub 不向来自 fork 的 pull request 提供 repository secrets。这类 PR 会运行
preflight，但其 `CI summary` 会明确失败，而不会给出假绿结果。维护者必须把
该 commit 放到能访问私有运行时 secrets 的同仓库分支复测；不要改用
`pull_request_target` 执行 PR 中的代码。
