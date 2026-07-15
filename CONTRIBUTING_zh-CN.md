# 为 JuliaForm 作贡献

[English](CONTRIBUTING.md) | **简体中文**

> [!NOTE]
> 本文件是规范英文贡献指南 [CONTRIBUTING.md](CONTRIBUTING.md) 的简体中文严谨
> 翻译，并非独立维护的规范。

感谢你有兴趣改进 `JuliaForm`！本文说明本地开发流程、Wolfram 到 Julia 渲染的
正确性要求，以及本仓库采用的提交消息规范。

`JuliaForm` 是一个面向 Wolfram Language 15.0+ 的 Paclet。它把 Wolfram
Language 表达式渲染为确定性的单行 Julia 源码，并且只公开一个符号：
`JuliaForm`。实现刻意保持精简，但变更仍需谨慎，因为语法有效的输出在 Julia
中仍可能具有不同的求值、数值、数组或索引语义。

## 设计要求

正确性优先于可接受表达式的数量。渲染器变更必须保持以下不变量：

- `JuliaForm` 必须是 `JuliaForm` 上下文中唯一的公共符号。
- 保持 Wolfram Language 的普通求值语义。只有调用者明确需要保留算术结构时
  才使用 `HoldForm`。
- 输出确定性的单行 UTF-8 Julia 源码。
- 当 Julia 具有忠实表示时保留精确值，包括整数、有理数、复数和任意精度实数。
- 显式跟踪 Julia 运算符优先级。括号会影响解析结果时，不能依赖视觉上看似
  合理的输出。
- 处理两种语言之间的语义差异，尤其是参数顺序、列表线程化、数组运算、相等
  关系和索引。
- 如果某个结构不存在普遍可靠的翻译，应使用 `JuliaForm::unsupported` 拒绝。
  如果无法为跨语言等价性作出充分论证，不要加入看似方便的映射。
- 文档和测试必须把 `Rule` 视为 Julia `Pair` 构造，而不是 Wolfram Language
  重写规则。

当未知符号头不需要特殊映射时，可以继续将其渲染为 Julia 调用。相反，
`Total`、`Length`、`Transpose` 和 `Norm` 等类型敏感的内置函数，不能仅仅因为
Julia 存在相似名称的操作就进行改名。

## 文档与翻译政策

英文是项目文档的规范源语言。需要维护的文档配对如下：

| 英文规范源 | 简体中文翻译 |
|---|---|
| `README.md` | `README_zh-CN.md` |
| `CONTRIBUTING.md` | `CONTRIBUTING_zh-CN.md` |
| `Documentation/English/ReferencePages/Symbols/JuliaForm.nb` | `Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb` |

新增的用户文档或贡献者文档必须遵循同一约定：英文 Markdown 使用不带语言后缀
的规范文件名，翻译在扩展名前加入 `_zh-CN`；Wolfram 原生文档则在
`Documentation/English` 与 `Documentation/ChineseSimplified` 之间配对。

每次文档变更都必须遵循以下顺序：

1. 首先编辑规范英文文件。
2. 确认英文文本在技术上准确，并明确其预期规范含义。
3. 在同一变更中更新配对的简体中文文件。
4. 对照最终英文规范源审校翻译，包括标题顺序、示例、代码、链接、精确标识符、
   版本号、要求、支持的行为和限制。
5. 将文档一致性检查与常规测试套件一起运行。

中文版本必须保留全部规范性内容和技术细节。不得省略限定条件、弱化要求或加入
独立的技术主张。只有在不改变英文含义的前提下，才可加入简短的译者澄清。除非
某段文本本身就是翻译对象，否则代码、标识符、字面输出、路径、版本和命令必须
逐字保持不变。

如果两种版本冲突或存在歧义，以英文规范源为准。发现偏差时，应在同一变更中
修复中文翻译。只要配对翻译仍然过时，文档变更就不完整。自动一致性检查可以
保护结构和代码示例，但不能取代对翻译准确性、完整性和表达自然度的人工审校。

## 开发环境

本仓库是 Wolfram Paclet，而不是 Julia package，因此没有 `Project.toml`、
registry 或 package 实例化步骤。

请安装以下工具：

1. Wolfram Language 15.0 或更高版本，包含 `PacletTools`。
2. Julia 的 LTS 与最新稳定版，用于复现完整 CI 矩阵。
3. `wolframscript`，用于测试、生成验证数据和构建 Paclet。

仓库不假定操作系统或 Wolfram 安装路径。运行下列命令前，请确保
`wolframscript` 和 `julia` 可通过 `PATH` 访问。如果 `wolframscript` 无法定位
内核，可运行一次 `wolframscript -configure`，或为当前 shell 设置其文档所述
的环境变量：

```bash
export WolframKernel=/absolute/path/to/WolframKernel
```

若要在 Wolfram Language 会话中直接加载工作副本：

```wl
Needs["PacletTools`"];
PacletDirectoryLoad["/absolute/path/to/JuliaForm"];
Needs["JuliaForm`"];
```

修改 package 初始化或输出 Form 注册逻辑后，请使用全新内核，避免先前的目录
加载状态掩盖生命周期问题。

## 仓库结构

| 路径 | 用途 |
|------|---------|
| `PacletInfo.wl` | Paclet 名称、版本、兼容性和扩展 |
| `Kernel/init.wl` | SPF 初始化和公共符号保护 |
| `Kernel/JuliaForm.wl` | 渲染器和唯一导出的 API |
| `Documentation/English/ReferencePages/Symbols/JuliaForm.nb` | 规范的原生符号参考页 |
| `Documentation/ChineseSimplified/ReferencePages/Symbols/JuliaForm.nb` | 符号页的简体中文翻译 |
| `README.md` / `README_zh-CN.md` | 规范用户指南及其翻译 |
| `CONTRIBUTING.md` / `CONTRIBUTING_zh-CN.md` | 规范贡献指南及其翻译 |
| `LICENSE` | 随源码与 Paclet 归档分发的 MIT 许可证 |
| `Tests/JuliaForm.wlt` | Wolfram Language 单元测试和契约测试 |
| `Tests/RunTests.wls` | 使用全新内核运行 Wolfram 测试 |
| `Tests/JuliaValidation.wls` | 从测试表达式生成 Julia 源码 |
| `Tests/JuliaValidation.jl` | 解析并求值生成的 Julia 源码 |
| `Tests/ValidatePacletArtifact.wls` | 独立验证构建归档 |
| `Scripts/BuildPaclet.wls` | 构建文档和 `.paclet` 归档 |
| `Scripts/PacletBuildSupport.wl` | 构建两种文档语言并执行产物完整性门禁 |
| `.github/workflows/CI.yml` | 测试、构建并编排 dev 与稳定版本发布 |
| `.github/AUTOMATION.md` | 说明仓库中受版本控制的自动化契约 |
| `.github/scripts/check-repository-config.sh` | 运行本地与 CI 仓库配置门禁 |
| `.github/scripts/validate-repository-config.rb` | 验证 settings、rulesets、Dependabot 与工作流策略 |
| `.github/scripts/publish-paclet.sh` | 实现 GitHub Release 发布 |
| `.github/tests/publish-paclet/` | 使用本地 `gh` mock 测试发布与中断恢复 |
| `.github/dependabot.yml` | 维护不可变的 GitHub Action pin |
| `.github/repository-settings/*.json` | 可复用的 Actions 与 environment API payload |
| `.github/rulesets/protect-main.json` | 可导入的 main 分支历史保护 |
| `.github/rulesets/protect-version-tags.json` | 可导入的稳定版本 tag 保护规则 |
| `dist/` | 本地 `.paclet` 构建产物；不是源文件 |

本 package 使用 Wolfram 15.0 Structured Package Format。通过
`PackageExported` 声明公共符号；所有实现辅助符号必须保持文件私有。

## 运行测试

从仓库根目录运行 Wolfram Language 测试套件：

```bash
wolframscript -file Tests/RunTests.wls
```

该测试套件检查 package 加载、单符号 API、输出 Form 行为、求值与 holding
语义、渲染规则、明确拒绝路径，以及双语文档的结构一致性。结构检查通过并不能
证明翻译准确；还必须完成上文要求的人工审校。

然后运行跨语言验证：

```bash
wolframscript -file Tests/JuliaValidation.wls |
  julia --startup-file=no --check-bounds=yes Tests/JuliaValidation.jl
```

Wolfram 脚本把渲染器的真实输出写入标准输出。Julia 驱动程序读取该数据流，
验证每项结果都能完整解析，对可以安全比较值的用例求值，并执行必须在已记录
运行时边界失败的用例。语法、值和错误源码数量都是显式契约常量；只有同时加入
匹配的生成用例和断言时才能更新数量。Julia 驱动程序不会查找或启动 Wolfram，
也不包含特定操作系统的路径。它还可以接收一个路径作为唯一参数，从先前生成的
文件读取数据。

提交 pull request 或直接向 `main` push 前，请运行这两条命令。仓库中的
GitHub Actions 工作流会在向 `main` push、同仓库 pull request、merge queue
group、严格版本 tag 和手动运行时，使用 Wolfram Engine 15.0.0，在
Julia 的 `lts` 与 `latest` 通道上重复这两条路径。`latest` 通道使用
setup-julia 的 `'1'` 选择器，即最新稳定的 Julia 1.x。fork pull request 无法
获得 Wolfram secret，因此其 `CI summary` 会明确失败，直到维护者从同仓库
分支复测该 commit。

不读取 secret 的 `Repository config` 作业也是必需前置门禁。它按版本和归档
SHA-256 固定 actionlint，检查每个工作流 shell 脚本，精确验证受版本控制的
settings 与 rulesets，并运行发布器的本地 mock 套件。在 Linux amd64 上可运行：

```bash
bash .github/scripts/check-repository-config.sh
```

变更行为时：

- 加入聚焦的 `VerificationTest`，使其具有唯一、描述性的 `TestID`，并将其
  放入 `Tests/JuliaForm.wlt`。
- 如果 Julia 解析属于契约的一部分，在 `Tests/JuliaValidation.wls` 中加入要
  输出的源码。
- 如果结果不依赖 Julia Base 之外的定义即可求值，在
  `Tests/JuliaValidation.jl` 中加入值断言。
- 当某个语义边界容易被意外跨越时，同时覆盖成功输出和邻近的不支持用例。
- 测试必须具有确定性，并且不依赖用户初始化文件。

## 实现风格

- 遵循现有 Wolfram Language 风格：四空格缩进、使用描述性的 lower-camel-case
  私有辅助符号，以及以 `$` 为前缀的 package 常量。
- `Kernel/init.wl` 只负责 package 初始化。渲染逻辑放在
  `Kernel/JuliaForm.wl` 中。
- 使用 `HoldComplete` 和显式 held wrapper 保留 held 结构。审查每个新辅助函数，
  避免意外求值。
- 渲染器分支返回 `{source, precedence}`。分配正确的优先级，并使用现有括号
  辅助函数，不要盲目拼接嵌套表达式。
- 复用 `juliaString` 和标识符辅助函数进行转义。生成的源码必须安全处理反斜杠、
  引号、控制字符、`$`、Julia 关键字和非标准 Wolfram 上下文。
- 对不安全的翻译使用 `failUnsupported`，诊断信息应清楚指出不支持的结构或
  语义类别。
- 除非新的依赖对于渲染器不可或缺且已经明确讨论，否则保持 Paclet 无依赖。
- 当公共契约、支持的映射表、文档所述限制、工具要求或验证基线发生变化时，
  首先更新规范的英文 README 和符号页；随后在同一变更中审校并同步两份简体
  中文翻译。

## Pull Request 检查清单

请求审查前，请确认：

- 除非已经明确同意扩展 API，否则变更保持单符号公共 API。
- 已分别考虑 Wolfram 求值行为和 held 表达式行为。
- 已为每个新映射检查 Julia 优先级、标量与数组行为以及类型语义。
- Wolfram Language 测试套件和跨语言验证均已通过。
- 干净 Paclet 构建和独立 artifact validator 均已通过。
- 兼容性或用户可见行为变化时，`PacletInfo.wl` 和规范英文 README 已更新。
- 公共契约、示例、支持的映射或限制变化时，规范英文 `JuliaForm` 符号页已更新。
- 每个发生变更的英文文档文件，都已在配对的简体中文翻译中获得完整且技术上
  忠实的更新。
- 已逐对比较标题结构、代码示例、命令、链接、标识符、版本、要求和限制。
- 文档一致性检查已通过，并且中文措辞也已接受人工翻译审校。
- 正常源码变更中不包含生成的 `.paclet` 归档。

## 构建与发布

正常贡献不应在 `dist/` 下添加文件；`.paclet` 归档是被忽略的构建产物。从仓库
根目录构建与 CI 相同的归档：

```bash
wolframscript -file Scripts/BuildPaclet.wls
```

脚本从自身位置解析仓库根目录，并把归档写入先清空的 `dist/`，因此不依赖调用
者的绝对路径或陈旧输出。它会显式构建英文和简体中文 notebook 与全部三类索引，
打包 MIT 许可证，再验证精确 Paclet 契约、manifest 哈希、索引、Kernel 文件集
及完整大小/SHA-256 inventory。构建后还应运行独立门禁；它还会测试 7 种
fail-closed 产物损坏：

```bash
wolframscript -file Tests/ValidatePacletArtifact.wls
```

每次成功的 CI 测试运行都会把归档上传为短期 workflow artifact。向 `main`
push 还会通过 GitHub `dev` environment 传递已测试的 artifact，并更新 `dev`
tag 对应的滚动预发布版本。发布器先上传 commit 唯一的资产，重新下载并验证
SHA-256，通过后才移动 tag，最后删除陈旧资产，因此中断后可恢复。只有发布作业
具有 release 写权限；pull request、merge queue group 和手动运行永远不会发布。
environment 部署策略应把 `dev` 限制到 `main`，把 `release` 限制到 `v*.*.*`
tag。

应从仓库 `Settings` → `Rules` → `Rulesets` 导入
`.github/rulesets/protect-main.json` 和
`.github/rulesets/protect-version-tags.json`。保持两者 active 且不配置 bypass
actor。main 规则允许直接快进 push，同时阻止删除分支和改写历史。CI 会验证
每个已经进入 main 的 commit，只有通过后 dev 发布器才会更新滚动预发布版本。
tag 规则允许创建新的 `v*` tag，但会阻止创建后的任何更新与删除，同时让滚动
`dev` tag 保持可变。不要启用仓库级 release immutability，因为该设置也会锁定
dev prerelease。

滚动 `dev` 预发布版本不是稳定的版本化 release。要发布稳定版本：

1. 按语义化版本规则提升 `"Version"`（位于 `PacletInfo.wl` 中）。
2. 当支持的行为或验证基线变化时，更新规范英文 README 和原生符号页，随后审校
   并同步其简体中文翻译。
3. 在干净的工作副本中运行两条完整测试路径。
4. 构建 `.paclet` 归档，确认文件名、嵌入的元数据和内容都使用新版本。
5. 创建并 push 匹配的 `vMAJOR.MINOR.PATCH` tag；不要将归档作为源文件提交：

   ```bash
   git tag v0.2.0
   git push origin refs/tags/v0.2.0
   ```

两个 Julia 矩阵项都通过后，CI 会创建稳定的 GitHub Release，并附加经过测试的
归档、重新下载验证 SHA-256，最后才发布。tag 版本与 Paclet 版本必须完全一致。
CI 可以恢复字节一致的 draft，但拒绝同名而内容不同的资产，也拒绝修改已经发布
的稳定 Release。如果最终发布响应丢失，重跑只有在规范 metadata、唯一资产及
远端 SHA-256 全部一致时，才会以只读方式成功。不得移动、删除或复用已发布的
版本 tag；需要修正时应发布新的补丁版本。

## 提交消息规范

### 格式

```text
<scope>(<target>): <subject>

<body>

<footer>
```

- 每行不得超过 72 个字符。
- 所有提交消息均使用英文。

### 主题行

- 不得超过 50 个字符。
- 使用祈使语气（例如使用 `add`，而不是 `added` 或 `adding`）。
- 结尾不加句号。
- 除非第一个词是专有名词，否则以小写字母开头。

### Scope 与 Target

scope 标识变更影响的仓库部分。

| Scope | 含义 | Target 示例 |
|-------|---------|----------------|
| `kernel` | SPF loader 或渲染器实现 | `precedence`, `indexing` |
| `test` | Wolfram 或 Julia 验证测试 | `rendering`, `unsupported` |
| `docs` | 用户文档和贡献者文档 | `readme`, `contributing` |
| `paclet` | Paclet 元数据和打包 | `metadata`, `build` |
| `ci` | 自动验证工作流 | `tests`, `setup` |
| `release` | 版本提升和 release 发布 | `v0.2.0` |
| `repo` | 仓库日常维护 | `gitignore`, `license` |

- `target` 是受影响的符号、渲染器区域、文件或组件，不含路径前缀或文件扩展名。
- 当多个辅助函数共同实现一种行为时，优先使用 `indexing` 或
  `held-evaluation` 等语义 target，而不是内部辅助函数名称。
- 当一个提交同等影响多个 scope 时，用 `&` 连接，并用一个 target 标识主要
  行为。例如，`kernel&test(indexing)` 表示一个实现变更，其回归测试同样处于
  核心地位。不要对附带影响使用 `&`，例如渲染器变更附带的小幅 README 澄清。
- 对于 `release` scope，`target` 是新版本 tag。

### 正文

- 与主题行之间空一行。
- 使用祈使语气。
- 解释为什么需要变更，而不是只说明改了哪些文件。
- 每行保持在 72 个字符以内。
- 列举不同理由或约束时使用无序列表（`-`）。

### 页脚

- AI 辅助的提交必须按下文说明包含 `Assisted-by` trailer。
- 完全由人完成的提交不需要页脚 trailer。
- 不要使用 `Co-authored-by` 表示 AI 署名；只能使用 `Assisted-by`。

### 主题动词

| 场景 | 推荐动词 | 示例 |
|----------|-------------------|---------|
| 新映射 | `add`, `implement`, `introduce` | `kernel(functions): add logarithm mapping` |
| 移除行为 | `remove`, `delete` | `kernel(functions): remove unsafe mapping` |
| 修复缺陷 | `fix`, `correct` | `kernel(precedence): fix nested powers` |
| 完善行为 | `update`, `revise`, `refine` | `kernel(indexing): refine span endpoints` |
| 测试 | `add`, `cover`, `extend` | `test(unsupported): cover held list calls` |
| 文档 | `document`, `clarify` | `docs(readme): clarify Pair semantics` |
| 重构 | `refactor`, `rename`, `reorganize` | `kernel(strings): centralize escaping` |
| 打包 | `update`, `harden` | `paclet(metadata): raise Wolfram minimum` |
| 发布 | `bump`, `release` | `release(v0.2.0): bump minor for mappings` |
| CI 或工具 | `add`, `update`, `harden` | `ci(tests): add cross-language validation` |

### AI 署名

本政策遵循
[Linux Kernel AI Coding Assistants](https://docs.kernel.org/process/coding-assistants.html)
指南中的原则。

#### 格式

```text
Assisted-by: AGENT_NAME:MODEL_NAME
```

#### 规则

- AI 工具不得添加 `Signed-off-by` tag。只有人类才能对 Developer Certificate
  of Origin 作出认证。
- 人类提交者必须审查所有 AI 生成的内容，并对贡献承担全部责任。
- 使用多个 AI 工具辅助时，每个工具各写一行 `Assisted-by`。
- 不要使用 `Co-authored-by` 表示 AI 署名。

#### 规范 Agent 名称

`AGENT_NAME` 必须与下列条目之一完全一致：

| AGENT_NAME | 说明 |
|------------|-------------|
| `ClaudeCode` | Anthropic Claude |
| `GitHub-Copilot` | GitHub Copilot |
| `OpenCode` | OpenCode CLI |
| `Codex` | OpenAI Codex |

若要加入新的 agent，请在 `CONTRIBUTING.md` 的此表末尾追加一行。

#### 规范 Model 名称

`MODEL_NAME` 应使用小写字母，并可包含版本号或描述符，以精确标识模型，例如
`gemini-3.1-pro-preview`、`glm-5.1` 或 `claude-opus-4.6`。

#### 示例

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
