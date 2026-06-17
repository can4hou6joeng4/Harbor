# 对外发布首个 GitHub Release

## Goal

把当前 ReaderMacApp 真正发布到 GitHub Releases,让外部用户可以从 Release 下载 `Reader.dmg`,拖入 Applications 安装,并让后续 Sparkle 自动更新链路从 `appcast.xml` 开始工作。

## What I already know

* 本地 `main` 已包含发布实现提交 `093e143 feat: 添加发布分发与自动更新`、任务归档提交 `4573c51`、日志提交 `b7938b2`。
* 任务启动时,远端 `origin/main` 仍在 `b156e10`,尚未包含 release workflow / Sparkle / appcast 相关提交。
* 任务启动时,远端没有 `v*` tag,`gh release list` 为空。
* GitHub Actions secret `SPARKLE_PRIVATE_KEY` 已存在。
* `.github/workflows/release.yml` 已存在,tag `v*` 会触发 DMG 构建、Sparkle 签名、Release 创建和 appcast 回写。

## Completion Notes

* 发布完成后,`origin/main` 已包含发布实现与 workflow 回写的 `appcast.xml`。
* GitHub tag / Release `v0.1.0` 已公开可访问,并包含 `Reader.dmg`。
* 详细验证证据见 `info.md`。

## Assumptions

* 首个公开版本使用 `v0.1.0`,与打包脚本默认 `SHORT_VERSION=0.1.0` 保持一致。
* 先推送 `main`,再创建并推送 `v0.1.0` tag,让 workflow 在包含 release workflow 的提交上运行。
* 发布后需要监控 GitHub Actions,确认 Release asset 与 appcast 均可用。

## Requirements

* 推送本地 `main` 到 `origin/main`。
* 创建并推送首个 release tag `v0.1.0`。
* 监控 GitHub Actions release workflow 到完成。
* 验证 GitHub Release 存在且包含 `Reader.dmg`。
* 验证远端 `appcast.xml` 被 workflow 回写,且 item 指向 `v0.1.0` 的 DMG。
* 如 workflow 失败,定位失败步骤并修复,不要留下半发布状态不说明。

## Acceptance Criteria

* [x] `origin/main` 包含当前发布实现提交。
* [x] GitHub tag `v0.1.0` 存在。
* [x] GitHub Release `v0.1.0` 存在且包含 `Reader.dmg`。
* [x] Release workflow 成功完成。
* [x] `https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml` 含 `v0.1.0` item、`sparkle:edSignature`、`length` 和 `sparkle:minimumSystemVersion=13.0`。
* [x] 发布结果记录到任务 `info.md` 并归档。

## Definition of Done

* 公开 Release 可访问。
* Appcast 可供 Sparkle 检查更新使用。
* Git 工作区干净。
* Trellis 任务归档并记录日志。

## Out of Scope

* Apple Developer ID 签名和公证。
* App Store 发布。
* GitHub Pages 托管 appcast。

## Technical Notes

* Key files: `.github/workflows/release.yml`, `appcast.xml`, `script/package_app.sh`, `script/update_appcast.py`.
* Current recommended tag: `v0.1.0`.
