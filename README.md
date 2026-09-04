<div align="center">

## 微图相册管家 Weitu

![Version badge][Version badge]
![Build badge][Build badge]

微图相册管家（Weitu）是一款面向 Android 的本地相册与媒体资源管理应用，基于 Flutter 构建，由 [Aves](https://github.com/deckerst/aves) 二次开发而来，针对国内使用环境做了去 Google 化改造。

[<img src="https://raw.githubusercontent.com/deckerst/common/main/assets/get-it-on-github.png"
      alt='从 GitHub 获取'
      height="80">](https://github.com/weimi95/weitu/releases/latest)

<div align="left">

## 功能特性

微图相册管家可管理各类图片与视频，既涵盖常见的 JPEG、MP4，也支持更特殊的格式，如 **多页 TIFF、SVG、老式 AVI 等**！

它会扫描你的媒体库，识别 **动态照片（Motion Photo）**、**全景照片（Photo Sphere）**、**360° 视频**，以及 **GeoTIFF** 文件。

**浏览与检索** 是微图的核心能力，目标是让你能在相册、照片、标签、地图之间顺畅切换。

微图深度集成 Android（含 Android TV），支持 **桌面小组件**、**应用快捷方式**、**屏保** 与 **全局搜索**，同时可作为 **媒体查看器与选择器** 使用。

## 截图

以下为应用界面示意（界面设计沿用 Aves）：

<div align="center">

[<img src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/1.png"
      alt='Collection screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/1.png)
[<img
      src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/2.png"
      alt='Image screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/2.png)
[<img
      src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/5.png"
      alt='Stats screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/5.png)
[<img
      src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/3.png"
      alt='Info (basic) screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/3.png)
[<img
      src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/4.png"
      alt='Info (metadata) screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/4.png)
[<img
      src="https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/readme/en/6.png"
      alt='Countries screenshot'
      width="130" />](https://raw.githubusercontent.com/deckerst/aves_extra/main/screenshots/play/en/6.png)

<div align="left">

## 更新日志

历史与计划中的变更见 [CHANGELOG](https://github.com/weimi95/weitu/blob/develop/CHANGELOG.md)。

## 权限说明

微图相册管家需要以下权限才能正常工作：
- **读取共享存储内容**：仅访问媒体文件；修改文件需用户显式授权。
- **读取媒体中的位置信息**：用于展示媒体坐标，并按国家/地区归类（反向地理编码）。
- **网络访问**：用于地图视图（已去除 Google 地图依赖，地图以基础模式呈现）及反向地理编码。
- **查看网络连接**：用于检测网络状态，优雅降级依赖网络的功能。

## 参与贡献

### 问题反馈

欢迎提交 [Bug 报告](https://github.com/weimi95/weitu/issues/new?assignees=&labels=type%3Abug&template=bug_report.yml&title=) 与 [功能建议](https://github.com/weimi95/weitu/issues/new?assignees=&labels=type%3Afeature&template=feature_request.yml&title=)。提问可前往 [Discussions](https://github.com/weimi95/weitu/discussions)。

### 代码

当前阶段本项目 **暂不接收外部 PR**。

## 构建与运行

构建前请先配置签名：创建 `<app dir>/android/key.properties`，参考 [key_template.properties](https://github.com/weimi95/weitu/blob/develop/android/key_template.properties)。

运行：
```
# ./flutterw run -t lib/main_play.dart --flavor play
```

调试 Kotlin 代码时，若 Android Studio 无法附加调试器：
1) 在 Android Studio 中打开 `android` 目录，
2) `Edit Configurations...`，
3) 选择 `app` 配置，
4) 切到 `Debugger` 标签，
5) 切到 `LLDB Post Attach Commands` 标签，
6) 添加：
```
process handle SIGSEGV --pass true --stop false --notify true
```

## 致谢

微图相册管家（Weitu）是基于 [Aves](https://github.com/deckerst/aves)（作者 deckerst）的二次开发版本。

与原项目相比，微图相册管家做了 **去 Google 化** 改造：移除了 Firebase / Crashlytics 数据上报、Google 地图服务等依赖，默认以本地 / 基础模式运行，更适合国内网络环境直接使用。

感谢 deckerst 及 Aves 的所有贡献者打造了这款优秀的开源相册应用，也感谢各位翻译与测试志愿者。本项目遵循原项目的开源许可，详见 [LICENSE](LICENSE)。

[Version badge]: https://img.shields.io/github/v/release/weimi95/weitu?include_prereleases&sort=semver
[Build badge]: https://img.shields.io/github/actions/workflow/status/weimi95/weitu/build-apk.yml?branch=develop
