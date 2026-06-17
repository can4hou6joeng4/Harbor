<div align="center">
  <img src="docs/reader-icon.png" alt="Reader" width="176" />
  <h1>Reader</h1>
  <p><em>本地优先的 Mac 阅读与收藏 —— 抓取、阅读、整理,并用你自带的 AI 做摘要 / 翻译 / 对话 / 二次创作。</em></p>
</div>

<p align="center">
  <a href="https://github.com/can4hou6joeng4/ReaderMacApp/releases/latest"><img src="https://img.shields.io/github/v/release/can4hou6joeng4/ReaderMacApp?style=flat-square&color=D2973F" alt="Release"></a>
  <a href="https://github.com/can4hou6joeng4/ReaderMacApp/releases"><img src="https://img.shields.io/github/downloads/can4hou6joeng4/ReaderMacApp/total?style=flat-square" alt="Downloads"></a>
  <a href="https://github.com/can4hou6joeng4/ReaderMacApp/stargazers"><img src="https://img.shields.io/github/stars/can4hou6joeng4/ReaderMacApp?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple" alt="macOS 13+">
  <a href="https://github.com/can4hou6joeng4/ReaderMacApp/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/can4hou6joeng4/ReaderMacApp/release.yml?style=flat-square&label=release" alt="Build"></a>
</p>

<p align="center"><strong>数据全在本地。无后端、无中间服务器,只有你的 Mac。</strong></p>

---

## ✨ 功能特性

- **采集** —— URL 正文提取 + 封面、RSS / Atom / JSON 订阅(去重、条件请求、并发同步)、本地 PDF/图片导入。
- **阅读** —— 三栏布局、划词高亮与笔记、双语对照、衬线/排版调节、阅读进度与位置记忆。
- **整理** —— 标签、树形目录、收藏、SQLite FTS5 全文搜索(中英文)、条目删除、键盘导航。
- **AI(自带 Key)** —— 摘要(结构化)、翻译(逐段保 id)、对话与二次创作(流式输出);结果回流落库,离线可读。
- **本地优先** —— 库 / 高亮 / 笔记 / 阅读位置全部本地持久化;AI 默认关闭、显式开启、绝不自动发送。

## 📦 下载安装

1. 从 [**Releases**](https://github.com/can4hou6joeng4/ReaderMacApp/releases/latest) 下载 `Reader.dmg`。
2. 打开 DMG,把 **Reader** 拖进 **Applications**。
3. 首次打开 —— 当前版本未做 Apple 公证,需放行一次 Gatekeeper:在「应用程序」里**右键 Reader → 打开**,或在终端执行:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Reader.app
   ```

## 🔄 自动更新

App 菜单 **Reader → 检查更新…** 即可。更新由 [Sparkle](https://sparkle-project.org) 分发,经 EdDSA 签名校验,不必再去网站手动下载。

## 🤖 配置 AI(自带 Key)

在应用内「设置」选择 Provider 并填入 Key(**只存 Keychain**):

- **Anthropic 官方** —— 默认 `api.anthropic.com`。
- **Anthropic 兼容网关 / 自定义端点** —— 填 Base URL + 鉴权方式(API Key 或 Auth Token)+ 模型;模型支持 `xxx[1m]` 写法(自动转 1M 上下文)。可直接**粘贴连接配置**(形如 `{"env":{"ANTHROPIC_BASE_URL":...,"ANTHROPIC_AUTH_TOKEN":...},"model":...}`)一键导入。
- **OpenAI / OpenAI 兼容** —— 填 Base URL(可指向本地 Ollama / LM Studio)+ 模型。

> AI 处理会把所选内容发送到你配置的端点;其余数据始终只在本地。

## 🔒 数据与隐私

- 数据库:`~/Library/Application Support/ReaderMacApp/reader.sqlite`
- API Key:macOS Keychain(按 Provider 隔离,不写入磁盘明文)
- 不收集、不上传任何遥测;唯一的对外请求是你主动触发的 AI 调用与订阅抓取。

## 🛠 从源码构建

```bash
swift build                  # 编译
swift test                   # 全部单测
./script/build_and_run.sh    # 开发期:拼最小 .app 并运行
./script/package_app.sh      # 打包成品:dist/Reader.app + dist/Reader.dmg
```

## 📐 技术栈与架构

Swift 5.9 / SwiftUI / macOS 13+,SwiftPM 单工程,原生 `URLSession`(AI 与抓取均无第三方 SDK)。依赖 [GRDB](https://github.com/groue/GRDB.swift)(SQLite/FTS5)、[SwiftSoup](https://github.com/scinfu/SwiftSoup)(正文提取)、[FeedKit](https://github.com/nmdias/FeedKit)(订阅解析)、[Sparkle](https://github.com/sparkle-project/Sparkle)(自更新)。

```
Sources/
  ReaderCore/        # 纯逻辑,与 UI 解耦,可单测
    AI/              # AIService 协议 + Anthropic / OpenAI 兼容 + Prompts + Keychain
    Capture/         # HTTPClient / 正文提取 / RSS 同步 / 附件导入
    Persistence/     # Repository 协议 + GRDB 实现 + 迁移(含 FTS5)
  ReaderMacApp/      # SwiftUI 界面(App / Views / Support)
Tests/               # 91 个单测(零真实网络,mock 传输 + fixture)
```

---

<div align="center"><sub>以本地优先为原则构建 · 数据归你所有</sub></div>
