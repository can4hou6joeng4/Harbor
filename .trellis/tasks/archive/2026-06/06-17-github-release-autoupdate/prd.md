# GitHub 发布分发 + Sparkle 自更新(免签名路线)

## Goal

让用户能在 GitHub Releases **下载 DMG → 拖进 Applications 安装**,并通过 **Sparkle** 在本地**检查/应用更新**。采用免 Apple 开发者账号的**未签名(ad-hoc)路线**:首次安装用户需手动放行 Gatekeeper,更新完整性由 Sparkle 的 EdDSA 签名保证(不依赖 Apple 公证)。配套 GitHub Actions 在打 tag 时自动构建并发布。

## What I Already Know

* 仓库已公开:`https://github.com/can4hou6joeng4/ReaderMacApp`,`origin` 已配置,`main` 已推送;`gh` 已登录 `can4hou6joeng4`。
* 已有 `script/package_app.sh`:release 构建 → `dist/Reader.app` + `dist/Reader.dmg`,**ad-hoc 签名 + hardened runtime**,默认 `ENABLE_APP_SANDBOX=0`(沙盒会破坏 ad-hoc 下的 Keychain),Info.plist 由脚本生成(含版本/图标/类别),图标 `Resources/AppIcon.icns`。
* 本机**无 Developer ID 证书**,不做公证;用户选择了免费分发 + 公开仓库。
* 部署目标 macOS 13;App 入口 `Sources/ReaderMacApp/App/ReaderMacApp.swift`(`@main` + `WindowGroup` + `.commands { CommandMenu("Reader") }`)。
* **已知坑(必须正面处理)**:① 未公证 App 下载后会被 quarantine,首次需 `xattr -dr com.apple.quarantine` 或右键打开;② **Sparkle 对 ad-hoc/未签名 App 的自更新有摩擦**——Sparkle 2 主要靠 EdDSA 归档签名做完整性校验,但其"更新后代码签名一致性检查"对 ad-hoc(每次签名不稳定)可能报错,需要据实配置/验证,必要时记录限制。

## Scope Decision

做:Sparkle 集成(依赖 + 更新器 UI + Info.plist 字段注入)、appcast 生成与托管、EdDSA 密钥流程、GitHub Actions 发布工作流、README 安装/更新说明。
不做:Apple 公证 / Developer ID 签名、App Store、沙盒启用、改产品功能。

## Requirements

### 1. Sparkle 集成
* 给 `ReaderMacApp` target 加 SwiftPM 依赖 [Sparkle 2](https://github.com/sparkle-project/Sparkle)。
* App 内提供「检查更新…」入口(`CommandMenu("Reader")` 里加一项,或标准 About/菜单),接 `SPUStandardUpdaterController`(自动检查可开,默认询问用户)。
* `package_app.sh` 生成的 Info.plist **注入** `SUFeedURL`(appcast 的稳定 URL)与 `SUPublicEDKey`(Sparkle EdDSA 公钥);`SUEnableAutomaticChecks` 视情设。
* App 仍能 `swift build` 且 `build_and_run.sh`/`package_app.sh` 正常。

### 2. EdDSA 密钥与 appcast
* 用 Sparkle 的 `generate_keys` 生成密钥对:**公钥**写入 Info.plist(`SUPublicEDKey`,可提交)、**私钥**仅作为 GitHub Actions secret `SPARKLE_PRIVATE_KEY`(**绝不提交**);在 `info.md`/README 记录生成步骤与"私钥存哪"。
* `appcast.xml`:每次发布追加一个 `<item>`(version、shortVersionString、`sparkle:edSignature`(由 `sign_update` 对 DMG 生成)、`length`、`enclosure url`=该 Release 的 DMG 下载直链、`sparkle:minimumSystemVersion=13.0`、发布说明链接)。
* **appcast 托管**:提交 `appcast.xml` 到仓库,`SUFeedURL` 指向 `https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`;CI 发布时更新并提交它。

### 3. GitHub Actions 发布工作流(`.github/workflows/release.yml`)
* 触发:推送 tag `v*`。runner:`macos-14`(或可用的 macos-latest)。
* 步骤:checkout → `swift build -c release` → `SHORT_VERSION=<tag 去 v> ./script/package_app.sh` 产出 DMG → 用 `SPARKLE_PRIVATE_KEY` 对 DMG `sign_update` 得 edSignature → 生成/更新 `appcast.xml`(enclosure 指向即将创建的 Release 资产 URL)→ `gh release create <tag>` 上传 `Reader.dmg` → 提交回 `appcast.xml`(到 main)。
* 失败要可见;不在日志打印私钥。

### 4. README 安装与更新说明
* 「下载安装」:从 Releases 下 `Reader.dmg` → 拖入 Applications → **首次放行 Gatekeeper**(右键打开,或 `xattr -dr com.apple.quarantine /Applications/Reader.app`),说明这是因为未公证。
* 「自动更新」:App 菜单「检查更新…」,Sparkle 经 EdDSA 校验更新完整性。

## Acceptance Criteria

* [ ] `.github/workflows/release.yml` 存在且语义正确(本地用 `act` 或人工审读流程;至少 YAML 合法、步骤完整)。
* [ ] Sparkle 依赖加入,App 内「检查更新…」菜单存在;`swift build` 通过;`package_app.sh` 产出的 Info.plist 含 `SUFeedURL` 与 `SUPublicEDKey`(`/usr/libexec/PlistBuddy -c "Print SUFeedURL"` 可读出)。
* [ ] `appcast.xml` 模板/生成脚本正确:item 含 version / enclosure url / edSignature / length / minimumSystemVersion;`SUPublicEDKey` 与签名私钥配对(用 `sign_update` + 公钥本地验签一条样例 DMG 通过)。
* [ ] EdDSA **私钥不在仓库**(`git grep` 无私钥);公钥已入 Info.plist;密钥与 secret 设置步骤写入 README/info.md。
* [ ] README 有「下载安装(含 Gatekeeper 放行)」与「自动更新」两节。
* [ ] 本地回归:`swift build && swift test && ./script/build_and_run.sh --verify` 全绿;`package_app.sh` 仍出 `.app`+`.dmg`。
* [ ] **手动验证记录(info.md)**:本地 `package_app.sh` 出的 DMG,用公钥对其 `sign_update` 产物验签通过;Sparkle「检查更新」在无新版本时正常(不崩);如对 ad-hoc App 的更新安装存在限制(坑②),据实记录与缓解方式。

## Definition Of Done

* 打 tag 即可经 CI 产出可下载 DMG 的 Release + 更新后的 appcast;用户可下载安装并经 Sparkle 自更新。
* 未签名路线的两处摩擦(首次 Gatekeeper、Sparkle 对 ad-hoc 的处理)都有明确说明与验证。
* 不改产品功能;开发/打包既有流程不破。

## Out Of Scope

* Apple 公证 / Developer ID(脚本/文档可留"有账号后如何加")、沙盒启用。
* GitHub Pages 托管 appcast(用 raw main 即可)、delta 增量更新、多渠道分发。

## Technical Notes

* 关键文件:`.github/workflows/release.yml`(新)、`appcast.xml`(新,提交)、`script/package_app.sh`(改:注入 `SUFeedURL`/`SUPublicEDKey`,可加 `--feed-url`/`--ed-pubkey` 参数或常量)、`ReaderMacApp.swift`(加 Sparkle 更新器 + 菜单项)、`Package.swift`(加 Sparkle 依赖)、README。
* Sparkle 工具:`generate_keys`(出密钥)、`sign_update`(对 DMG 出 edSignature),随 Sparkle SPM 产物提供;CI 里可 `swift build` 后从 artifacts 取,或用 Sparkle 发布的二进制。
* `SUFeedURL` = `https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`。enclosure url = `https://github.com/can4hou6joeng4/ReaderMacApp/releases/download/<tag>/Reader.dmg`。
* ad-hoc + Sparkle:优先保证 EdDSA 校验链通;若 Sparkle 因代码签名不稳定拒绝安装更新,记录所需最小配置(或说明未签名下的限制),不要为此引入伪造签名。
* 不破坏 `ENABLE_APP_SANDBOX=0` 默认与 Keychain 可用性。
