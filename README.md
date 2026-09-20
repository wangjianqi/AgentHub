# AgentHub

AgentHub 是一个原生 macOS SwiftUI 本地管理工具，用于统一查看和管理 AI Coding 工具的 MCP、Skills、Agents、Hooks、Plugins 与配置文件。

第二版开始不再是纯只读扫描工具，已支持部分安全写入能力。所有写入操作都会先自动备份原配置文件。

## 已支持平台

- Claude Code
- OpenAI Codex
- Tencent CodeBuddy
- Alibaba Qoder (`QODER_CONFIG_DIR`)
- Qoder CN / 通义灵码兼容目录
- ByteDance TRAE / TraeCode
- Qwen Code
- Moonshot Kimi Code
- Baidu Comate
- OpenClaw
- OpenCode / opencode

## 第二版功能

| 功能 | 状态 | 说明 |
|---|---:|---|
| 本地扫描 | 已支持 | 扫描安装状态、配置文件、MCP、Skills、Agents、Hooks、Plugins |
| MCP 启用 / 停用 | 已支持 | 对 JSON/JSONC 写入 `disabled` 字段；对 TOML 写入 `disabled = true/false` |
| 修改前自动备份 | 已支持 | 备份到 `~/Library/Application Support/AgentHub/Backups` |
| 备份 Diff | 已支持 | 对比备份文件和当前文件 |
| MCP 静态可用性检查 | 已支持 | 检查 command 是否存在，远程 URL / npx / uvx 等会标记为需确认 |
| 平台间迁移 | 已支持 | 可复制迁移片段，也可写入目标平台用户级配置 |
| Profile 分组 | 已支持 | 按场景保存 MCP 组合，例如 iOS 开发、Web 开发、App Store 上架 |
| 风险提示 | 已支持 | 检测远程包执行器、管道执行脚本、sudo/rm -rf、敏感 key/token 等 |

## 重要说明

1. **启用/停用 MCP 会改配置文件**，但会先自动备份。
2. JSONC 文件写入后会被格式化为标准 JSON，注释会丢失。关键配置建议先手动备份一次。
3. MCP 静态可用性检查不会自动执行完整 MCP Server，也不会做 JSON-RPC 握手，避免在不明确的情况下运行第三方代码。
4. 迁移 MCP 时，环境变量只会保留 key 名称，真实值会写成 `<FILL_ME>`，需要你手动补齐。
5. Profile 当前用于“场景化分组和导出清单”，不会自动批量启停配置，避免误改大量 MCP。

## 已支持扫描内容

| 类型 | 说明 |
|---|---|
| 安装状态 | 综合检测 CLI、常见 macOS `.app`、工具专属配置痕迹；避免仅依赖 PATH |
| MCP Servers | 解析 JSON / JSONC / TOML 配置中的 `mcpServers`、`mcp_servers`、`mcp`、`servers` |
| Skills | 扫描 `SKILL.md` |
| Agents | 扫描 agents 目录中的 md/json/jsonc/yaml/toml/txt 文件 |
| Hooks | 静态解析配置中的 hooks/hook 字段 |
| Plugins | 解析 plugin/plugins 字段，并扫描 OpenCode 插件目录 |

## 主要配置路径

### Claude Code

- `~/.claude.json`
- `~/.claude/settings.json`
- `.mcp.json`
- `.claude/settings.json`
- `.claude/settings.local.json`
- `~/.claude/skills`
- `.claude/skills`
- `~/.claude/agents`
- `.claude/agents`

### Codex

- `~/.codex/config.toml`
- `/etc/codex/config.toml`
- `.codex/config.toml`
- `~/.agents/skills`
- `.agents/skills`
- `/etc/codex/skills`

### Tencent CodeBuddy

- `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/.mcp.json`（推荐）
- `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/mcp.json`（旧版兼容）
- `~/.codebuddy.json`（更旧版兼容）
- `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/skills`
- `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/agents`
- `.mcp.json` / `mcp.json`
- `.codebuddy/skills`
- `.codebuddy/agents`

### Alibaba Qoder

- `${QODER_CONFIG_DIR:-~/.qoder}/settings.json`
- `${QODER_CONFIG_DIR:-~/.qoder}/skills`
- `${QODER_CONFIG_DIR:-~/.qoder}/agents`
- `.qoder/settings.json`
- `.qoder/settings.local.json`
- `.qoder/skills`
- `.qoder/agents`

### Qoder CN / 通义灵码

- CLI：`qodercn`（兼容检测旧 `qoderclicn` 名称）
- `${QODERCN_CONFIG_DIR:-~/.qoder-cn}/settings.json`
- `${QODERCN_CONFIG_DIR:-~/.qoder-cn}/skills`
- `${QODERCN_CONFIG_DIR:-~/.qoder-cn}/agents`
- `~/.lingma/skills`
- `.qoder/skills`
- `.lingma/skills`

### ByteDance TRAE / TraeCode

- `~/.trae/traecli.toml`
- `~/Library/Application Support/trae_cli/trae_cli.yaml`
- `.trae/mcp.json`
- `~/.traecli/skills`
- `~/.trae-cn/skills`
- `.traecli/skills`
- `.trae/skills`
- `.traecli/agents`

### Qwen Code

- `${QWEN_HOME:-~/.qwen}/settings.json`
- `${QWEN_HOME:-~/.qwen}/skills`
- `.qwen/settings.json`
- `.qwen/skills`
- macOS system settings under `/Library/Application Support/QwenCode/`

### Kimi Code

- `${KIMI_CODE_HOME:-~/.kimi-code}/config.toml`
- `${KIMI_CODE_HOME:-~/.kimi-code}/mcp.json`
- `${KIMI_CODE_HOME:-~/.kimi-code}/skills`
- `${KIMI_CODE_HOME:-~/.kimi-code}/agents`
- `${KIMI_CODE_HOME:-~/.kimi-code}/plugins/installed.json`
- `~/.agents/skills` / `~/.agents/agents`
- `.kimi-code/*` / `.agents/*`

### Baidu Comate

- `.comate/mcp.json`
- `~/.comate/skills`
- `.comate/skills`
- `.agents/skills`

> Comate 4.0 的公开资料已确认 Skills 目录；当前不假设一个未公开稳定的 Comate CLI 可执行名，安装状态优先通过 macOS App 和配置/资源扫描判断。

### OpenClaw

- `~/.openclaw/openclaw.json`
- `~/.openclaw/skills`
- `~/.agents/skills`
- `.agents/skills`
- `skills`

### OpenCode / opencode

- `~/.config/opencode/opencode.json`
- `~/.config/opencode/tui.json`
- `opencode.json`
- `tui.json`
- `~/.config/opencode/plugins`
- `.opencode/plugins`
- `~/.config/opencode/agent`
- `~/.config/opencode/agents`
- `.opencode/agent`
- `.opencode/agents`

## 扩展新平台

新增平台不需要改主扫描流程，只需要在 `Sources/AgentHub/Services/PlatformRegistry.swift` 中新增一个 `PlatformDefinition`。

示例：

```swift
PlatformDefinition(
    tool: .openCode,
    executableName: "opencode",
    versionArgs: [["--version"], ["-v"]],
    configFiles: [
        ConfigPathSpec(root: .home, path: ".config/opencode/opencode.json", scope: .user, format: .jsonc),
        ConfigPathSpec(root: .workspace, path: "opencode.json", scope: .project, format: .jsonc)
    ],
    skillDirectories: [],
    agentDirectories: [
        DirectorySpec(root: .home, path: ".config/opencode/agents", scope: .user),
        DirectorySpec(root: .workspace, path: ".opencode/agents", scope: .project)
    ],
    pluginDirectories: [
        DirectorySpec(root: .home, path: ".config/opencode/plugins", scope: .user),
        DirectorySpec(root: .workspace, path: ".opencode/plugins", scope: .project)
    ],
    extraConfigPathHints: ["~/.config/opencode"]
)
```

如果新增的是完全不同的配置格式，只需要增加新的 `ConfigFormat`，并在 `AgentScanner.scanConfigFile` 中接入对应解析器。

## 运行

```bash
open Package.swift
```

或者：

```bash
swift run AgentHub
```

> 注意：这是 macOS SwiftUI 项目，需要在 macOS 上运行。本环境无法完整编译 SwiftUI/AppKit，但核心 Foundation 扫描与编辑模块已做语法解析检查。

## Internationalization

AgentHub uses Xcode String Catalogs:

- `Sources/AgentHub/Resources/Localizable.xcstrings`
- Source language: English (`en`)
- Supported languages: English (`en`) and Simplified Chinese (`zh-Hans`)
- No other languages are bundled by default.

The app includes a **Language** menu in the macOS menu bar. You can switch between English and Simplified Chinese without restarting the app. The toolbar also includes a language switcher for convenience.

Runtime language selection is persisted in `UserDefaults` under:

```text
AgentHub.AppLanguage
```

When adding new UI text, add a stable key to `Localizable.xcstrings` and call:

```swift
L("your.localization.key")
```

For formatted strings:

```swift
L("message.example", value)
```


## Platform coverage (2026-09)

AgentHub scans both CLI and common macOS application installations, plus user/project configuration artifacts. Current registry coverage includes:

- Claude Code
- OpenAI Codex (including `~/.agents/skills`, project `.agents/skills`, and `/etc/codex/skills`)
- Tencent CodeBuddy (`CODEBUDDY_CONFIG_DIR`, MCP, Skills, sub-agents, hooks/plugins declared in settings)
- Alibaba Qoder (`QODER_CONFIG_DIR`)
- Qoder CN / Lingma compatibility directories (`QODERCN_CONFIG_DIR`, current CLI `qodercn`)
- ByteDance TRAE / TraeCode (CLI + IDE, TOML/JSON and legacy YAML MCP configuration)
- Qwen Code (`QWEN_HOME`, MCP, Skills, macOS system settings)
- Moonshot Kimi Code (`KIMI_CODE_HOME`, MCP, directory/flat-file Skills, installed plugin records)
- Baidu Comate (macOS App, project MCP, native/shared Agent Skills)
- OpenClaw
- OpenCode

### Scanner behavior

- Installation detection checks known CLI executables first, then common `/Applications` and `~/Applications` app bundles.
- If a known tool-specific configuration file remains but no CLI/App is found, the installation state is reported as ambiguous instead of installed. Shared Skill roots such as `~/.agents/skills` are deliberately not used as installation evidence.
- YAML MCP configuration is scan-only. AgentHub will not rewrite YAML files, preventing accidental format corruption.
- JSONC scanning supports comments and trailing commas.
- Kimi Code flat `skills/<name>.md` Skills are recognized only at the Skill root; nested Markdown references are not misclassified.
