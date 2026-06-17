# Reader — 本地优先的 Mac 阅读与收藏应用

一款数据全在本地的 macOS 阅读器:采集网页/RSS/附件,统一阅读与整理,并用你自带的 AI Key 做摘要、翻译、对话与二次创作。原生 SwiftUI,单一 SwiftPM 工程,无后端、无中间服务器——你的内容只在你的设备上。

> 状态:功能完整、可双击运行的成品(`dist/Reader.dmg`)。AI 四能力已在真实模型上端到端验证。

---

## 功能

- **采集**:URL 抓取(正文提取 + 封面)、RSS/Atom/JSON Feed 订阅(去重、条件请求、并发同步)、本地附件导入(PDF 提取全文、图片)。
- **阅读**:三栏布局、划词高亮/笔记(原生 NSTextView 浮层)、双语对照、衬线/排版调节、阅读进度与位置记忆。
- **整理**:标签、树形目录、收藏、全文搜索(SQLite FTS5,中英文)、条目删除、键盘导航。
- **AI(BYO-Key)**:摘要(结构化)、翻译(逐段保 id)、对话(流式)、二次创作(流式 Markdown)。结果回流落库,离线可读。
- **本地优先**:库/高亮/笔记/收藏/阅读位置全部持久化;AI 默认关闭、显式开启、绝不自动发送。

## 技术栈与架构

- Swift 5.9 / SwiftUI / macOS 13+;SwiftPM 单工程,原生 `URLSession`(AI 与抓取均无第三方 SDK)。
- 依赖:[GRDB](https://github.com/groue/GRDB.swift)(SQLite/FTS5)、[SwiftSoup](https://github.com/scinfu/SwiftSoup)(正文提取)、[FeedKit](https://github.com/nmdias/FeedKit)(订阅解析)、[Sparkle](https://sparkle-project.org/)(应用内更新)。

```
Sources/
  ReaderCore/            # 纯逻辑,与 UI 解耦,可单测
    AI/                  # AIService 协议 + Anthropic / OpenAI-compatible + Prompts + Keychain
    Capture/             # HTTPClient / 正文提取 / RSS 同步 / 附件导入
    Persistence/         # Repository 协议 + GRDB 实现 + 迁移
    ReaderModels.swift / ReaderStore.swift / SampleLibrary.swift
  ReaderMacApp/          # SwiftUI 界面(App / Views / Support)
Tests/                   # 91 个单测(零真实网络,mock 传输 + fixture)
```

设计约束沉淀在 `.trellis/spec/guides/`(持久化 / 内容采集 / AI 接入三份约束性指南)。

## 构建与运行

```bash
swift build                      # 编译
swift test                       # 跑全部单测
./script/build_and_run.sh        # 开发期:拼最小 .app 并运行
```

## 打包交付

```bash
./script/package_app.sh          # release 构建 → dist/Reader.app + dist/Reader.dmg
```

- ad-hoc 签名 + hardened runtime,本机双击即可运行;图标程序化生成(`script/make_app_icon.swift`)。
- 打包脚本会嵌入 Sparkle framework,并写入 `SUFeedURL` 与 `SUPublicEDKey`。默认更新源为 `https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`。
- 沙盒默认关闭(ad-hoc + App Sandbox 会破坏 Keychain);拿到 Apple Developer ID 后可 `ENABLE_APP_SANDBOX=1 ./script/package_app.sh` 启用,并自行加签名 + 公证用于对外分发。

## 下载安装

1. 在 [GitHub Releases](https://github.com/can4hou6joeng4/ReaderMacApp/releases) 下载 `Reader.dmg`。
2. 打开 DMG,把 `Reader.app` 拖入 Applications。
3. 首次打开时,由于当前免费分发版本未做 Apple Developer ID 公证,macOS Gatekeeper 可能阻止启动。可右键 `Reader.app` 选择「打开」并确认,或在终端执行:

```bash
xattr -dr com.apple.quarantine /Applications/Reader.app
```

这是未公证分发的系统限制;应用包本身仍使用 ad-hoc 签名 + hardened runtime,更新包完整性由 Sparkle EdDSA 签名校验。

## 自动更新

应用菜单「Reader」→「检查更新...」会通过 Sparkle 读取 `appcast.xml`,校验 DMG 的 EdDSA 签名后提示安装。当前未签名路线下,首次安装仍需按上节手动放行 Gatekeeper;Sparkle 安装更新时也可能受到 ad-hoc 代码签名一致性限制,如遇安装失败,重新从 Releases 下载 DMG 覆盖安装即可。

发布维护者需要先设置 GitHub Actions secret:

```bash
/path/to/Sparkle/bin/generate_keys --account com.bobochang.ReaderMacApp
/path/to/Sparkle/bin/generate_keys --account com.bobochang.ReaderMacApp -x /tmp/readermacapp-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY --repo can4hou6joeng4/ReaderMacApp < /tmp/readermacapp-sparkle-private-key
rm -f /tmp/readermacapp-sparkle-private-key
```

`SUPublicEDKey` 可以提交到仓库;`SPARKLE_PRIVATE_KEY` 只存在 GitHub Actions secret 中,不得提交。

## 配置 AI(自带 Key)

应用内「设置」中选择 Provider 并填入 Key(只存 Keychain),支持:

- **Anthropic 官方**:默认 `api.anthropic.com`。
- **Anthropic 兼容网关 / 自定义端点**:填 Base URL + 鉴权方式(API Key 或 Auth Token)+ 模型;模型支持 `xxx[1m]` 写法(自动转 1M 上下文 beta 头)。可直接「粘贴连接配置」(形如 `{"env":{"ANTHROPIC_BASE_URL":...,"ANTHROPIC_AUTH_TOKEN":...},"model":...}`)一键导入。
- **OpenAI / OpenAI-compatible**:填 Base URL(可指向本地 Ollama/LM Studio)+ 模型。

> AI 处理会把所选内容发送到你配置的 Provider/端点;其余数据始终只在本地。

## 数据位置

- 数据库:`~/Library/Application Support/ReaderMacApp/reader.sqlite`(沙盒模式下为应用容器内对应路径)。
- API Key:macOS Keychain(按 Provider 隔离),不写入磁盘明文。

## 开发方式

本项目以 [Trellis](.trellis/) 任务流推进:每个增量一个任务(PRD → 实现 → 归档),配套约束性设计指南与对抗式 code review。开发历程见 `.trellis/tasks/archive/`。

## 不在范围内(可选后续)

- X / 微博 / YouTube 真实抓取(协议位已留)。
- 本地模型(Apple Foundation Models / Ollama)原生实现。
- App Store 上架、Developer-ID 公证。
