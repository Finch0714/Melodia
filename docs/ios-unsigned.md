# Melodia iOS 无签名 IPA

这个目录新增了一个原生 SwiftUI iOS 客户端。它复用网易云音乐的公开接口协议，并通过 GitHub Actions 在 macOS 上编译、打包为 **未签名 IPA**。

## 为什么走 GitHub Actions

IPA 必须由 Xcode 构建。Windows 上的 xtool 方案需要 WSL、Swift 6.4、Apple ID 和体积很大的 Xcode.xip，本机目前也没有安装 WSL，因此这里选择更简单的 GitHub macOS Runner。

因此推荐流程是：

1. 把 `iosApp/` 与 `.github/workflows/ios-unsigned.yml` 推送到 GitHub。
2. 打开仓库的 **Actions** 页面。
3. 选择 **Build unsigned iOS IPA**，点击 **Run workflow**。
4. 等构建完成后下载 artifact：`Melodia-unsigned-ipa`。
5. 解压后得到 `Melodia-unsigned.ipa`。

工作流使用 `macos-15` runner、XcodeGen 和 `xcodebuild`，关闭了所有代码签名配置。构建目标架构为 `arm64`，最低系统版本为 iOS 16.0。

## 当前构建

- 仓库：<https://github.com/Finch0714/Melodia>
- Actions 页面：<https://github.com/Finch0714/Melodia/actions/workflows/ios-unsigned.yml>
- 工作流：`Build unsigned iOS IPA`
- 产物 artifact：`Melodia-unsigned-ipa`，解压后为 `Melodia-unsigned.ipa`

工作流已经配置为在 `iosApp/**` 变更推送到 `main` 时自动运行，也可以在 Actions 页面手动点击 **Run workflow**。

已对构建产物做过如下校验：

- `Payload/Melodia.app/Melodia` 为 arm64 Mach-O 可执行文件
- Bundle ID 为 `com.lin0721.linmusic`
- 包内没有 `_CodeSignature` 目录，也没有 `embedded.mobileprovision`
- 搜索、播放直链和歌词接口均通过 EAPI 实测返回 `code: 200`

## 安装方式

**未签名 IPA 不能直接通过 iTunes、Finder 或 Apple Configurator 安装。** 需要下面任一方式：

- **TrollStore**：在 TrollStore 支持的 iOS 版本上直接导入 IPA，由 TrollStore 完成签名和安装。
- **Sideloadly / AltStore**：使用自己的 Apple ID 重新签名后安装。免费开发者账号通常需要每 7 天续签一次。

如果直接用系统安装未签名包，通常会出现“无效的 App”或签名校验失败。

## 当前功能

- 网易云个性化推荐歌单与排行榜
- 歌曲搜索
- 歌单详情与批量补齐歌曲
- EAPI / WeAPI 请求加密
- AVPlayer 播放、后台播放、上一首/下一首
- 全屏播放器、进度拖动
- LRC / YRC 歌词与翻译
- 网易云扫码登录
- 手动 Cookie 登录
- 登录后每日推荐

## 暂未移植

- 本地音乐扫描与标签编辑
- 插件系统
- 听歌识曲
- 云盘上传
- 下载管理
- 网易云评论、播客、动态等完整业务
- Android/桌面端视觉的逐项复刻

## 技术结构

```text
iosApp/
  project.yml                  XcodeGen 工程定义
  Melodia/
    MelodiaApp.swift            App 入口
    AppModel.swift              首页、登录状态、二维码登录
    Network/
      NeteaseCrypto.swift       AES / MD5 / RSA
      BigUInt.swift             无第三方依赖的 RSA 大数运算
      NeteaseClient.swift       EAPI / WeAPI 请求
      Models.swift              Codable 数据模型
    Player/
      PlayerEngine.swift        AVPlayer 与后台播放
      Lyrics.swift              LRC / YRC 解析
    Views/                      SwiftUI 页面
```

## 常见问题

**构建失败在 `xcodegen` 或 Swift 编译阶段**

在 Actions 运行日志中查看具体文件与行号。工作流失败时会额外上传 artifact `ios-build-log`。

**登录二维码一直等待**

二维码接口依赖网易云 Web 登录状态。可以展开“使用 Cookie 登录”，从浏览器登录 `music.163.com` 后复制包含 `MUSIC_U` 的 Cookie。

**歌曲无法播放**

部分歌曲受版权、VIP 或地区限制，接口可能只返回试听片段或空地址。登录有权限的账号后重试。

**想改 Bundle ID**

修改 `iosApp/project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`。无签名构建本身不依赖 Bundle ID，但重新签名安装时建议使用自己的唯一 ID。

## 免责声明

本项目仅用于个人学习和技术交流。音乐、封面、歌词等内容的版权归网易云音乐及原权利人所有。
