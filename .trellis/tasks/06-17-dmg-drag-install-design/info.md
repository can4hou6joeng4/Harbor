# 实现与验证记录

## 实现

- 新增 `script/make_dmg_background.swift`,用 AppKit/CoreGraphics 程序化生成暖纸 + 琥珀风格 DMG 背景。
- 新增提交产物:
  - `Resources/dmg-background.png` (`660x400`)
  - `Resources/dmg-background@2x.png` (`1320x800`)
- 新增 `script/dmg_settings.py`,通过 headless `dmgbuild` 写入 Finder 布局:
  - window `660x400`
  - `Reader.app` 左侧
  - `Applications` 右侧
  - icon size `128`
  - 隐藏 toolbar/sidebar/status/pathbar
  - `symlinks = {"Applications": "/Applications"}`
- `script/package_app.sh` 新增:
  - `--regenerate-dmg-background`
  - `DMGBUILD_BIN` 环境变量
  - 有 `dmgbuild` 时生成设计版 DMG
  - 无 `dmgbuild` 时回退原始 `hdiutil -srcfolder` 朴素 DMG
- `.github/workflows/release.yml` 改为在 runner 临时 venv 安装 `dmgbuild`,避免 PEP 668 / externally-managed Python 环境问题。

## Headless 设计说明

- 采用 `dmgbuild`,不使用 Finder / `osascript`。
- `dmgbuild` 直接创建镜像、复制内容并写 `.DS_Store`,适合 GitHub Actions `macos-14` headless runner。
- `dmgbuild` 会把实际 Finder 背景合成为卷根 `.background.tiff`;为了验收和可检查性,`create_hook` 额外复制 `.background/dmg-background.png` 与 `.background/dmg-background@2x.png` 到 DMG 内。

## 本机设计版 DMG 验证

命令:

```bash
python3 -m venv /tmp/readermacapp-dmgbuild-venv
/tmp/readermacapp-dmgbuild-venv/bin/python -m pip install dmgbuild
DMGBUILD_BIN=/tmp/readermacapp-dmgbuild-venv/bin/dmgbuild ./script/package_app.sh --regenerate-dmg-background
```

结果:

- `hdiutil verify dist/Reader.dmg`: passed
- `codesign --verify --strict dist/Reader.app`: passed
- `SUFeedURL`: `https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`
- `SUPublicEDKey`: present

挂载检查:

```text
Reader.app: True
Applications symlink: True
.DS_Store: True
.background dir: True
background png: True
background @2x png: True
dmgbuild background tiff: True
Applications target: /Applications
```

卷内结构摘要:

```text
.DS_Store
.background/
.background/dmg-background.png
.background/dmg-background@2x.png
.background.tiff
Applications -> /Applications
Reader.app
```

## 回退路径验证

命令:

```bash
DMGBUILD_BIN=/tmp/not-a-real-dmgbuild ./script/package_app.sh
```

结果:

- 输出 `dmgbuild not found; creating plain DMG fallback`
- `hdiutil verify dist/Reader.dmg`: passed
- 保持 `Reader.app` + `Applications` 链接的朴素 DMG 输出。

## 回归验证

- `bash -n script/package_app.sh`: passed
- `python3 -m py_compile script/dmg_settings.py`: passed
- `swiftc script/make_dmg_background.swift -o /tmp/make_dmg_background_check`: passed
- `swift build`: passed
- `swift test`: passed, 91 tests, 0 failures
- `./script/build_and_run.sh --verify`: passed
- `open -n dist/Reader.app` + `pgrep -x ReaderMacApp`: launched, then stopped with `pkill -x ReaderMacApp`
- 严格 secret 扫描: no hits

## 注意事项

- `dist/` 仍为生成目录,不提交。
- CI venv 只安装 `dmgbuild`,不触碰 Sparkle private key;签名 appcast 逻辑不变。
