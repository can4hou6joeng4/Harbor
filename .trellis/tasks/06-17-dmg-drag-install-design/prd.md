# 设计版拖拽安装 DMG(背景图 + 箭头 → Applications)

## Goal

把现在朴素的 DMG 升级为**设计版拖拽安装窗口**:自定义背景图(暖纸 + 琥珀,与应用图标同语言)、左侧 App 图标、右侧 Applications 文件夹、中间「拖入安装」箭头与文案——达到 tw93/Mole 级的呈现。**关键约束:必须在无 GUI 的 GitHub Actions runner 上也能产出**(headless 可用),不破坏签名/启动/Sparkle 自更新链。

## What I Already Know

* 现状 `script/package_app.sh` 用 `hdiutil create -srcfolder` 出**朴素 DMG**(只有 `Reader.app` + `/Applications` 符号链接,默认 Finder 窗口、无背景)。`.github/workflows/release.yml` 在打 tag 时调用它产出并发布 DMG。
* `script/make_app_icon.swift` 是现成的 **CoreGraphics 程序化绘图** 生成器范例(暖米白底 ≈`#F4F1EA`、琥珀 ≈`#D2973F`、书+R),DMG 背景可同法生成。
* **真坑(必须规避)**:经典「osascript + Finder 设置窗口/图标位置」方案**依赖 GUI 会话,在 headless CI 上不可靠/失败**。
* CI runner:`macos-14`,headless;已可 `pip3`/`python3`。

## Scope Decision

做:程序化生成 DMG 背景 + 用 headless 工具(dmgbuild)布局 + 改打包脚本 + CI 装依赖。
不做:Apple 公证、真实界面截图(README)、Finder-osascript 布局方案。

## Requirements

### 1. DMG 背景图(程序化生成)
* 仿 `make_app_icon.swift`,新增生成器(CoreGraphics/AppKit)产出 `Resources/dmg-background.png` 与 `Resources/dmg-background@2x.png`(@2x 双倍像素)。
* 视觉:暖米白底,左侧留出放 App 图标的位置、右侧留出 Applications 的位置,中间一条琥珀色**虚线箭头**指向右,顶部/底部一句文案(如「将 Reader 拖入 Applications 安装」);整洁、与图标同色系、无 AI 俗气渐变。窗口建议 ~660×400。
* 真实的 Reader 图标与 Applications 文件夹图标由 DMG 在 `icon_locations` 处叠加显示,背景图只画引导(占位框/箭头/文案)。

### 2. 用 headless 工具做布局(dmgbuild)
* 用 **[dmgbuild](https://github.com/dmgbuild/dmgbuild)**(纯 Python,直接写 `.DS_Store`,**不需 Finder/GUI**)做窗口与图标布局:`window_rect`、`background`(上面的 png)、`icon_size`、`icon_locations`(`Reader.app` 居左、`Applications` 居右)、隐藏工具栏/侧栏、`symlinks={'Applications':'/Applications'}`。
* 提供 dmgbuild 设置文件(如 `script/dmg_settings.py`),卷名 `Reader`。

### 3. 改 `package_app.sh`
* 若检测到 `dmgbuild` 可用 → 产出**设计版** DMG;否则**回退**现有 `hdiutil` 朴素 DMG(保证本机没装 dmgbuild 也能出包,不报错)。
* DMG 内容不变:含已签名 `Reader.app` + `/Applications` 链接;最终仍为压缩只读(UDZO)。
* 不改签名/Info.plist/Sparkle 注入逻辑。

### 4. CI(`release.yml`)
* 加一步安装 dmgbuild(实际采用 CI 临时 venv,避免 externally-managed Python 环境问题),使 tag 发布时产出设计版 DMG。其余流程(签名 appcast、建 Release、回写 appcast)不变。

## Acceptance Criteria

* [x] 本机(已装 dmgbuild)`./script/package_app.sh` 产出的 `dist/Reader.dmg`:挂载后窗口显示自定义背景、`Reader` 图标与 `Applications` 并排、箭头/文案可见;`hdiutil attach` 后卷内含 `.background/`(背景图)与 `.DS_Store`,`/Applications` 符号链接存在。
* [x] `Resources/dmg-background.png`(+@2x)由提交的生成器脚本可复现产出,并提交入库。
* [x] `dmgbuild` 不可用时,`package_app.sh` 回退朴素 DMG 且整体成功(脚本带分支与提示)。
* [x] `release.yml` 增加 dmgbuild 安装步骤,YAML 合法;不打印任何 secret。
* [x] 回归:`Reader.app` 仍能 `open` 启动;`codesign --verify --strict` 通过;`SUFeedURL`/`SUPublicEDKey` 仍注入;`swift build && swift test && ./script/build_and_run.sh --verify` 全绿。
* [x] `info.md` 记录:本机挂载 DMG 的布局核验证据(`ls -la /Volumes/Reader` + `.DS_Store`/`.background` 存在,或截图);并说明 CI headless 可用性(为何用 dmgbuild 而非 osascript)。

## Definition Of Done

* 用户从 Releases 下载 DMG 打开后,看到设计版「拖入 Applications」窗口。
* 本机与 CI 两条路径都能产出该 DMG;无 dmgbuild 时优雅回退。
* 不影响 App 启动、签名、Sparkle 自更新与既有测试。

## Out Of Scope

* Apple 公证 / Developer ID;App Store。
* README 真实界面截图(由用户后续运行 App 截图补 `docs/screenshots/`)。
* osascript+Finder 布局(headless 不可靠,明确不采用)。

## Technical Notes

* 关键文件:`script/make_dmg_background.swift`(或并入现有图标生成器,新增子命令)、`Resources/dmg-background.png`(+@2x,提交)、`script/dmg_settings.py`(dmgbuild 配置)、`script/package_app.sh`(改 DMG 生成段)、`.github/workflows/release.yml`(装 dmgbuild)。
* dmgbuild 用法:`dmgbuild -s script/dmg_settings.py -D app=dist/Reader.app "Reader" dist/Reader.dmg`;settings 用 `defines`(`app`)+ `files=[app]` + `symlinks={'Applications':'/Applications'}` + `icon_locations` + `background` + `window_rect`。
* 背景建议 660×400(@2x 1320×800);`icon_size` ~128;`Reader.app` 约 (165,170)、`Applications` 约 (495,170)、箭头/文案画在背景中部。
* CI:用 `${RUNNER_TEMP}/dmgbuild-venv` 安装 `dmgbuild`,再把 venv `bin` 写入 `GITHUB_PATH`。
* 保持 `ENABLE_APP_SANDBOX=0` 默认与 Keychain 可用性不变。
