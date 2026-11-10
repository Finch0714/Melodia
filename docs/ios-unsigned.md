# Melodia iOS 未签名 IPA

本目录提供原生 SwiftUI iOS 客户端，复用网易云音乐公开接口，并通过 GitHub Actions 在 macOS Runner 上编译、打包为 **未签名 IPA**。

## 构建流程

1. 将 `iosApp/` 或 `.github/workflows/ios-unsigned.yml` 的变更推送到 `main`。
2. GitHub Actions 自动运行 **Build unsigned iOS IPA**。
3. 构建完成后下载 artifact `Melodia-unsigned-ipa`。
4. 解压后得到 `Melodia-unsigned.ipa`。

工作流使用 `macos-15`、XcodeGen 和 `xcodebuild`，关闭全部代码签名配置。构建目标为 `arm64`，最低系统版本为 iOS 16.0。

## 当前构建

- 仓库：<https://github.com/Finch0714/Melodia>
- Actions：<https://github.com/Finch0714/Melodia/actions/workflows/ios-unsigned.yml>
- 当前版本：`1.2.1 (5)`
- 目标提交：`be95eb80`
- 构建运行：<https://github.com/Finch0714/Melodia/actions/runs/42761205492>
- SHA256：`55796F78E53B2EEAD50916D532A00852013350610CF96B8EBA0F7F62ED2EF228`
- Release：<https://github.com/Finch0714/Melodia/releases/tag/ios-1.2.1-2026-11-10>
- 直接下载：<https://github.com/Finch0714/Melodia/releases/download/ios-1.2.1-2026-11-10/Melodia-unsigned.ipa>
- 国内镜像：<https://v4.gh-proxy.org/https://github.com/Finch0714/Melodia/releases/download/ios-1.2.1-2026-11-10/Melodia-unsigned.ipa>

## 1.2.1 更新

- 播放页按 Android 原版参数重排：24pt 水平边距、6pt 封面圆角、来源栏内嵌、原版歌名/进度/播放控制/操作行尺寸。
- 旋转时不再通过 `.id` 强制重建播放页，移除整页裁剪，并保护零尺寸布局瞬间，修复横竖屏切换后元素消失和布局错乱。
- 原版逐字光块改用 CoreText 的真实字形与行盒坐标，不再按整行比例估算，修复白色半透明长方形与歌词错位。
- 封面与头像改为内存 + 磁盘缓存，同一 URL 请求去重，并请求网易云缩略图尺寸，减少重复下载和流量。
- 设置中的“清除缓存”会同时清理图片缓存。
- 保留歌词、评论、队列、分享和音质入口。

## 产物校验

- `Payload/Melodia.app/Melodia` 为 arm64 Mach-O 可执行文件。
- Bundle ID 为 `com.lin0721.linmusic`。
- 包内没有 `_CodeSignature` 目录，也没有 `embedded.mobileprovision`。
- `CFBundleShortVersionString=1.2.1`，`CFBundleVersion=5`。

## 安装方式

**未签名 IPA 不能直接通过 iTunes、Finder 或 Apple Configurator 安装。** 可选择：

- **TrollStore**：在 TrollStore 支持的 iOS 版本上直接导入 IPA。
- **Sideloadly / AltStore**：使用自己的 Apple ID 重新签名后安装。免费开发者账号通常需要每 7 天续签一次。

直接安装未签名包通常会出现“无效的 App”或签名校验失败。

## 当前功能

- 桌面客户端 EAPI 扫码登录，修复“客户端版本过低”
- 手动 Cookie 登录
- 网易云个性化推荐歌单、排行榜与每日推荐
- 搜索：单曲、歌单、专辑、歌手分类，热搜与搜索历史
- 歌单详情、专辑详情、歌手详情
- 我的歌单、收藏专辑、我喜欢的音乐、听歌排行
- 歌曲评论分页浏览
- AVPlayer 播放、后台播放、上一首 / 下一首
- 顺序播放、列表循环、单曲循环、随机播放
- 标准 / 较高 / 极高 / 无损音质选择
- 播放队列、红心收藏、歌词 / 评论 / 队列入口
- 设置页：音质、播放模式、歌词排版、逐字效果、外观、网络与缓存
- 播放页横竖屏自适应、进度条点击与拖动
- YRC 逐字歌词、Melodia 逐字流光、原版光块、LRC 歌词与翻译

## 暂未移植

- 本地音乐扫描与标签编辑
- 插件 / LX 音源
- 听歌识曲
- 云盘上传与下载管理
- MV、播客、电台、动态
- 评论发布与点赞交互
- Android/桌面端插件视觉的逐项复刻

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
      ImageCache.swift          内存/磁盘图片缓存
    Player/
      PlayerEngine.swift        AVPlayer 与后台播放
      Lyrics.swift              LRC / YRC 解析
    Views/                      SwiftUI 页面
```

## 常见问题

**构建失败在 `xcodegen` 或 Swift 编译阶段**

在 Actions 运行日志中查看具体文件与行号。工作流失败时会额外上传 artifact `ios-build-log`。

**登录二维码一直等待**

客户端已改用桌面客户端 EAPI 生成二维码。若仍失败，可以展开“使用 Cookie 登录”，从浏览器登录 `music.163.com` 后复制包含 `MUSIC_U` 的 Cookie。

**歌曲无法播放**

部分歌曲受版权、VIP 或地区限制，接口可能只返回试听片段或空地址。登录有权限的账号后重试。

**图片加载慢**

1.2.1 起图片会按显示尺寸请求网易云缩略图，并缓存到内存和 `Caches/MelodiaImages`；首次加载仍取决于当前网络到网易云图片 CDN 的速度。

**想改 Bundle ID**

修改 `iosApp/project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`。未签名构建本身不依赖 Bundle ID，但重新签名安装时建议使用自己的唯一 ID。

## 免责声明

本项目仅用于个人学习和技术交流。音乐、封面、歌词等内容版权归网易云音乐及原权利人所有。