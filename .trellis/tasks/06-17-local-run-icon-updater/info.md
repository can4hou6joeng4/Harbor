# 修复本地运行图标与更新提示 - 验证记录

## Root Cause

- 用户看到的无图标应用来自 `script/build_and_run.sh` 生成的 `dist/ReaderMacApp.app`，不是正式打包脚本生成的 `dist/Reader.app`。
- 旧的开发 bundle 没有 `Contents/Resources/AppIcon.icns`，Info.plist 也没有 `CFBundleIconFile`，因此 Dock/Finder 会显示通用应用图标。
- 旧的开发 bundle 缺少 `CFBundleVersion` / `CFBundleShortVersionString` 等发布元数据，但 App 启动时仍无条件创建 `SPUStandardUpdaterController(startingUpdater: true, ...)`。Sparkle 在启动 updater 失败时会显示标准错误 `Unable to Check For Updates`。

## Fix

- `script/build_and_run.sh`
  - 复制 `Resources/AppIcon.icns` 到开发 bundle。
  - 写入 `CFBundleDisplayName`、`CFBundleIconFile`、`CFBundleShortVersionString`、`CFBundleVersion`、`NSHighResolutionCapable`、`LSApplicationCategoryType` 等基础元数据。
  - 写入 `ReaderEnableSparkleUpdates=false`，并不再把 Sparkle feed/public key 写入开发 bundle。
- `Sources/ReaderMacApp/App/ReaderMacApp.swift`
  - 通过 `ReaderUpdateConfiguration.sparkleUpdatesEnabled` 读取 `ReaderEnableSparkleUpdates`。
  - 仅当开关为 `true` 时显示“检查更新...”菜单并创建 Sparkle updater。
- `script/package_app.sh`
  - 正式发布 bundle 写入 `ReaderEnableSparkleUpdates=true`，保留 Sparkle 自动更新能力。

## Verification

- Passed: `swift build`
- Passed: `swift test`
  - 91 XCTest tests passed.
- Passed: `./script/build_and_run.sh --verify`
- Passed: development bundle metadata check:
  - `CFBundleName=Reader`
  - `CFBundleDisplayName=Reader`
  - `CFBundleIconFile=AppIcon`
  - `CFBundleShortVersionString=0.1.0-dev`
  - `CFBundleVersion=63`
  - `ReaderEnableSparkleUpdates=false`
  - `SUFeedURL=<missing>`
  - `SUPublicEDKey=<missing>`
  - `SUEnableAutomaticChecks=<missing>`
  - `dist/ReaderMacApp.app/Contents/Resources/AppIcon.icns` exists.
- Passed: `codesign --verify --strict dist/ReaderMacApp.app`
- Passed: `./script/package_app.sh`
  - Generated `dist/Reader.app`.
  - Generated `dist/Reader.dmg`.
  - `hdiutil verify dist/Reader.dmg` valid.
  - Local machine does not have `dmgbuild`; script used the existing plain DMG fallback.
- Passed: release bundle metadata check:
  - `CFBundleName=Reader`
  - `CFBundleDisplayName=Reader`
  - `CFBundleIconFile=AppIcon`
  - `CFBundleShortVersionString=0.1.0`
  - `CFBundleVersion=63`
  - `ReaderEnableSparkleUpdates=true`
  - `SUFeedURL=https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`
  - `SUPublicEDKey` present.
  - `SUEnableAutomaticChecks=true`
- Passed: `codesign --verify --strict dist/Reader.app`
- Passed: `hdiutil verify dist/Reader.dmg`
- Passed: `git diff --check`
- Passed: recent logs did not show Sparkle `Fatal updater` / `Unable to Check` entries after the development bundle launch.
