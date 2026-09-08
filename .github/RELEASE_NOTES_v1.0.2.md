# 微图相册 v1.0.2 发布说明

## 核心变更：视频内核切换为 ExoPlayer（压体积）
- 视频播放内核由 libmpv（media_kit）切换为官方 ExoPlayer / Media3（video_player 插件 `aves_video_exo`）。
- **APK 体积大幅下降**：libmpv 原生库（各 ABI 合计约 30MB+）已完全移除，单 ABI release APK 由 1.0.1 的 ~52MB 降至 ~40MB 量级。
- 缩略图主路径仍为系统 MediaStore，网格缩略图不受影响。

## 已知限制（exo 路线）
- 应用内不支持音轨 / 字幕切换（`canSelectTrack=false`），与 mpv 路线不同。
- 视频元数据 fetcher 为最小 stub（缩略图兜底 / 慢动作识别降级），系统 MediaStore 有缩略图时不受影响。
- ExoPlayer + MediaCodec 硬解覆盖相册常见格式（mp4 / webm / mkv-H264 / HEVC）无问题；极少数冷门编码可能回退失败。

## 档位 2 布局（1.0.1 已含，本次沿用）
- 瀑布流（mosaic）按图片宽高比自适应；图片最多 70% 视口、文字最多 30% 视口，一屏可见下一张顶部，文字溢出在文本框内滚动。

## 下载
- `weitu-1.0.2-arm64-v8a.apk`：现代安卓手机
- `weitu-1.0.2-armeabi-v7a.apk`：老旧 32 位机
