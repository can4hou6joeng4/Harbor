# 修复本地运行图标与更新提示

## Goal

修复通过本地运行脚本重新打开 Reader 时出现 Sparkle 更新器启动失败弹窗、且 Dock/Finder 不显示项目图标的问题，使开发验证包和正式发布包在基础 bundle 元数据与图标资源上保持一致，同时避免本地 ad-hoc 开发包暴露会误导用户的更新失败提示。

## What I already know

- 用户截图显示 Reader 启动后弹出 `Unable to Check For Updates`，正文为 `The updater failed to start...`。
- 用户同时观察到重新打开的应用没有显示预期图标。
- `script/package_app.sh` 生成 `dist/Reader.app`，会复制 `Resources/AppIcon.icns` 到 bundle，并写入 `CFBundleIconFile=AppIcon`。
- `script/build_and_run.sh` 生成 `dist/ReaderMacApp.app`，目前没有创建 `Contents/Resources`、没有复制图标、没有写入 `CFBundleIconFile`。
- App 入口 `ReaderMacApp.swift` 在启动时构造 `SPUStandardUpdaterController(startingUpdater: true, ...)`，开发运行包 Info.plist 仍包含 Sparkle feed/public key。

## Assumptions

- 用户看到的问题来自本地运行脚本生成的 `dist/ReaderMacApp.app`，而不是正式发布 DMG 内的 `dist/Reader.app`。
- 正式发布包仍应保留 Sparkle 自动更新能力；本修复只应让本地开发/验证包不弹出错误并显示正确图标。

## Requirements

- 本地运行脚本生成的 app bundle 必须包含项目图标资源，并声明 `CFBundleIconFile`。
- 本地运行脚本生成的 app bundle 名称、显示名、版本等基础元数据应尽量与正式打包脚本一致，避免验证时看到与发布包不同的外观。
- 本地 ad-hoc 运行不应在启动时自动启动 Sparkle 更新器并弹出失败提示。
- “检查更新...”菜单在本地开发包中不应触发误导性的 Sparkle 错误；正式发布包仍可使用 Sparkle 检查更新。
- 不引入私钥、个人账号、证书或其他隐私信息。

## Acceptance Criteria

- [x] 通过 `script/build_and_run.sh --verify` 生成并打开的本地 app 能正常启动。
- [x] `dist/ReaderMacApp.app/Contents/Resources/AppIcon.icns` 存在，Info.plist 中包含 `CFBundleIconFile=AppIcon`。
- [x] 本地运行包启动时不再弹出 `Unable to Check For Updates`。
- [x] 正式打包脚本 `script/package_app.sh` 仍可生成带图标和 Sparkle 配置的 `dist/Reader.app` / `dist/Reader.dmg`。
- [x] `swift build` 与相关测试通过。

## Definition of Done

- 代码和脚本改动已最小化并通过本地验证。
- 任务相关变更已提交，提交信息符合 `type: 中文描述`。
- Trellis 任务归档并记录会话。

## Out of Scope

- 不发布新的 GitHub Release。
- 不更换 Sparkle feed、公钥或签名体系。
- 不处理 macOS Dock/Finder 图标缓存导致的历史显示延迟，只保证新生成 bundle 的资源和声明正确。

## Technical Notes

- 重点文件：
  - `script/build_and_run.sh`
  - `script/package_app.sh`
  - `Sources/ReaderMacApp/App/ReaderMacApp.swift`
  - `Resources/AppIcon.icns`
- 需要确认是否用 Info.plist 开关控制本地包禁用 Sparkle，以避免影响正式包。
