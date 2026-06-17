# 发布验证记录

## 结果

- 仓库: `can4hou6joeng4/ReaderMacApp`
- 可见性: `PUBLIC`
- 默认分支: `main`
- 发布版本: `v0.1.0`
- Release URL: `https://github.com/can4hou6joeng4/ReaderMacApp/releases/tag/v0.1.0`
- DMG 资产: `Reader.dmg`
- 资产大小: `5734855`
- 资产摘要: `sha256:cd32f250e8dcfef113db9f11fd226ea12f7a595f1bc92b8cba975bab68682e97`
- 发布时间: `2026-06-17T08:15:42Z`

## 执行动作

- 已推送 `main` 到 `origin/main`。
- 已创建并推送 annotated tag `v0.1.0`。
- Release workflow 成功创建 GitHub Release 并上传 `Reader.dmg`。
- Workflow 自动提交 `appcast.xml` 回写提交 `209b8b4 chore: 更新发布更新源`。
- 本地 `main` 已通过 `git pull --ff-only origin main` 快进到 `origin/main`。

## GitHub Actions

- Workflow: `Release`
- Run ID: `27675219014`
- URL: `https://github.com/can4hou6joeng4/ReaderMacApp/actions/runs/27675219014`
- 结果: `success`
- Job: `Build DMG and publish release`
- 关键步骤均成功: resolve dependencies, build release binary, package DMG, download Sparkle tools, sign update archive, update appcast, create GitHub release, commit appcast。

## Release 验证

- `gh release view v0.1.0 --repo can4hou6joeng4/ReaderMacApp` 显示:
  - `isDraft=false`
  - `isPrerelease=false`
  - asset `Reader.dmg`
  - `contentType=application/x-apple-diskimage`
  - `size=5734855`
- `curl -fsSLI https://github.com/can4hou6joeng4/ReaderMacApp/releases/download/v0.1.0/Reader.dmg` 最终返回 `HTTP/2 200`, `content-disposition: attachment; filename=Reader.dmg`, `content-length: 5734855`。

## Appcast 验证

远端 appcast URL:

```text
https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml
```

XML 解析断言通过:

- `title=Reader 0.1.0`
- `sparkle:version=1`
- `sparkle:shortVersionString=0.1.0`
- `sparkle:minimumSystemVersion=13.0`
- enclosure URL: `https://github.com/can4hou6joeng4/ReaderMacApp/releases/download/v0.1.0/Reader.dmg`
- `sparkle:edSignature` 非空
- `length=5734855`
- `type=application/octet-stream`

## 隐私与密钥检查

- GitHub Actions secret `SPARKLE_PRIVATE_KEY` 已存在于远端仓库 secret 中。
- 严格 secret 扫描无命中:
  - GitHub PAT
  - private key block
  - 长格式 `sk-...` API key
  - Sparkle private key assignment shape
  - WordPress app password assignment shape
  - Anthropic auth token assignment shape
- 宽松扫描仅命中允许项:
  - Sparkle 公钥 `SUPublicEDKey` / `SPARKLE_PUBLIC_ED_KEY`
  - GitHub Actions secret 变量名 `SPARKLE_PRIVATE_KEY`
  - README / spec 中的安全说明
  - 测试中的假 token / fake key

## 本地质量检查

- `swift build`: passed
- `swift test`: passed, 91 tests, 0 failures
- `hdiutil verify` on downloaded public `Reader.dmg`: passed

## 后续边界

- 当前发布是 GitHub Release + Sparkle appcast 可用状态。
- Apple Developer ID 签名与公证仍在本任务范围外; 外部用户首次打开可能仍会遇到 macOS Gatekeeper 提示。
