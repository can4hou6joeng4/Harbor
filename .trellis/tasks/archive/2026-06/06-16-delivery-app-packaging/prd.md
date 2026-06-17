# 交付化:打包可双击运行的 .app + 图标 + 签名 + DMG

## Goal

把当前 SwiftPM 可执行的 Reader 做成**可双击运行、可分发**的 macOS 成品:正式 Info.plist(版本/类别/图标)、应用图标(`.icns`)、代码签名(hardened runtime)、沙盒 entitlements(已准备 + 视可行性启用)、release 构建,并产出 `.app` 与 `.dmg`。**硬目标:产出的 `.app` 双击能正常启动,且 AI 调用(网络)、附件导入(文件选择)、API Key(Keychain)、本地数据库(持久化)四项都真正可用。** 不改产品功能,只做封装与交付。

## What I Already Know

* 当前是 SwiftPM 可执行(`swift build` → `.build/.../ReaderMacApp` 裸二进制);已有 `script/build_and_run.sh` 会拼一个**最小** `.app`(debug、Info.plist 字段很少、**无图标/无签名/无 entitlements**),用于开发期运行。
* 部署目标 macOS 13;`@main ReaderMacApp` + `WindowGroup` + `.windowStyle(.hiddenTitleBar)`;bundle id 现用 `com.bobochang.ReaderMacApp`。
* app target(ReaderMacApp)**无 SwiftPM 资源**(Fixtures 只在测试 target),所以 `.app` 只需放二进制 + 图标,无需拷 `.bundle`。
* 工具链可用:`iconutil`、`sips`、`codesign`、`hdiutil`、`swiftc`。
* 数据层 `GRDBRepository` 用 `FileManager.url(for: .applicationSupportDirectory…)`/Keychain(`APIKeyStore` 用 generic password,service 形如 `ReaderMacApp.AI.<provider>`)。
* **已知风险(必须处理,不能想当然)**:**App 沙盒 + ad-hoc 签名(无 Apple 开发者账号)很可能让 Keychain 读写失败**(`errSecMissingEntitlement`,因 keychain-access-group 依赖真实签名身份);沙盒还会把 Application Support 改到容器路径(数据迁移问题,样例数据可忽略)。本机用户**无 Developer ID**,只能 ad-hoc 签名。

## Scope Decision

做:`script/package_app.sh`(release → `.app` → 图标 → 完整 plist → 签名 → 校验 → DMG)、应用图标生成、entitlements、版本号。
不做:App Store 上架、Developer-ID 公证(notarization,无账号)、自动更新、改任何产品功能/UI。

## Requirements

### 1. 打包脚本 `script/package_app.sh`
* `swift build -c release` 取 release 二进制。
* 组装 `dist/Reader.app/Contents/{MacOS,Resources,Info.plist}`;拷二进制、`AppIcon.icns`。
* 写**完整 Info.plist**:`CFBundleExecutable`、`CFBundleIdentifier`(沿用 `com.bobochang.ReaderMacApp`)、`CFBundleName`、`CFBundleDisplayName=Reader`、`CFBundlePackageType=APPL`、`CFBundleShortVersionString`(如 `0.1.0`)、`CFBundleVersion`(构建号,可用 `git rev-list --count HEAD` 或日期)、`LSMinimumSystemVersion=13.0`、`NSHighResolutionCapable=true`、`CFBundleIconFile=AppIcon`、`LSApplicationCategoryType=public.app-category.news`、`NSHumanReadableCopyright`。
* 代码签名:`codesign --force --options runtime --entitlements <entitlements> --sign - dist/Reader.app`(ad-hoc + hardened runtime),`--timestamp=none`。
* 校验:`codesign --verify --strict dist/Reader.app` 通过;打印 `codesign -d --entitlements :- dist/Reader.app` 供核对。
* 产出 DMG:`dist/Reader.dmg`(含 `Reader.app` + 指向 `/Applications` 的符号链接;`hdiutil create` 即可,无需第三方)。
* 幂等可重跑;`MODE`/参数化版本号可选。保留 `build_and_run.sh` 作为开发期 runner 不破坏。

### 2. 应用图标(程序化生成,on-brand)
* 用**程序化绘制**(`swiftc` 编一个 AppKit/CoreGraphics 小工具,或等价方案)在 1024×1024 画出图标,再 `sips` 缩放成完整 `.iconset`(16/32/128/256/512 及 @2x),`iconutil -c icns` 生成 `Resources/AppIcon.icns`。**不要依赖外部图片或第三方库。**
* 视觉与产品一致(暖纸 + 琥珀):暖米白圆角底(≈`#F4F1EA`),中心一个克制的"阅读"意象(书页/文档或衬线字母 R),用琥珀强调色(≈`#D2973F`),整洁、macOS 风、无 AI 俗气渐变。
* 生成器脚本提交进 `script/`;生成的 `AppIcon.icns` 提交进仓库(让没装工具链也能打包)。

### 3. Entitlements 与沙盒(按可行性,Keychain 必须能用)
* 提供 `Resources/Reader.entitlements`,含:`com.apple.security.app-sandbox`、`com.apple.security.network.client`(AI/RSS/URL 抓取)、`com.apple.security.files.user-selected.read-write`(附件 NSOpenPanel)。
* **先尝试沙盒启用**;但**硬验收是「装出来的 .app 里 Keychain 存取真的能用」**。若 ad-hoc + 沙盒导致 Keychain 失败(见上风险),则:本机交付构建**默认关闭 app-sandbox**(仍保留 hardened runtime + 完整签名 + 完整 plist + 图标),并把沙盒 entitlements 文件与「拿到 Developer ID 后启用沙盒」的开关/说明保留在脚本与 `info.md`。**绝不交付一个无法保存 API Key 的沙盒应用。**
* 在 `info.md` 记录最终采用沙盒还是非沙盒、以及为什么(实测 Keychain 结果)。

## Acceptance Criteria

* [ ] `./script/package_app.sh` 一键产出 `dist/Reader.app` 与 `dist/Reader.dmg`,可重复运行。
* [ ] `dist/Reader.app` **双击/`open` 能启动并显示界面**(进程存活,无沙盒/签名导致的启动崩溃)。
* [ ] `codesign --verify --strict dist/Reader.app` 通过;`.app` 带 hardened runtime;entitlements 可被 `codesign -d --entitlements` 读出。
* [ ] **功能冒烟(交付构建内)**:Keychain 存/取 API Key 正常、SQLite 数据库写入并在重启后留存、AI 网络请求能发出(配 sub2api/Anthropic 后)、附件文件选择可用。GUI 无法截图时,以「启动后 DB 文件生成 + Keychain round-trip 不报 errSecMissingEntitlement + 一次真实 AI 调用成功」作为证据写入 `info.md`。
* [ ] `AppIcon.icns` 由提交的生成器可复现产出,`.app` 显示该图标(Finder/Dock)。
* [ ] `dist/Reader.dmg` 可挂载,内含 `Reader.app` + `Applications` 链接。
* [ ] `swift build && swift test && ./script/build_and_run.sh --verify` 仍全绿(不破坏开发流)。

## Definition Of Done

* 交付出一个本机双击可运行、带图标、已签名的 `Reader.app` 和 `Reader.dmg`。
* 沙盒采用与否有实测依据并记录;Keychain/DB/网络/文件四项在交付构建里确认可用。
* 不改产品功能;开发期 `build_and_run.sh` 不受影响。

## Out Of Scope

* App Store 上架、entitlement 审核;Developer-ID 公证 / `xcrun notarytool`(无账号)——但脚本/文档留出「有账号后如何加签名+公证」的说明。
* 自动更新(Sparkle 等)、深色图标变体、本地化。
* 任何功能/UI 改动。

## Technical Notes

* 关键产物:`script/package_app.sh`(新)、`script/make_app_icon.swift`(或等价生成器)、`Resources/AppIcon.icns`(提交)、`Resources/Reader.entitlements`(新)。
* ad-hoc 签名 = `codesign --sign -`;hardened runtime = `--options runtime`。ad-hoc 应用在**本机**可运行(Gatekeeper 对本机构建放行);分发到他机需 Developer ID + 公证,属 out of scope。
* 沙盒下 DB 路径会变成 `~/Library/Containers/com.bobochang.ReaderMacApp/Data/Library/Application Support/…`,属正常;非沙盒为 `~/Library/Application Support/…`。
* DMG:`hdiutil create -volname Reader -srcfolder <staging> -ov -format UDZO dist/Reader.dmg`,staging 内放 `Reader.app` + `ln -s /Applications`。
* 版本:可在脚本顶部定义 `SHORT_VERSION=0.1.0`,`BUILD=$(git rev-list --count HEAD)`。
