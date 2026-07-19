<p align="center">
  <img src="assets/logo.png" width="96" height="96" alt="SuperIsland" />
</p>

<h1 align="center">SuperIsland 中文说明书</h1>

<p align="center">
  <a href="README.en.md">English README</a> · <strong>简体中文</strong> ·
  <a href="https://github.com/dearfaint/SuperIsland/releases">下载 Release</a>
</p>

SuperIsland 将 MacBook 刘海区域扩展为可交互的灵动岛，用于显示媒体播放、电池、天气、日历、通知、文件暂存、股票行情、电脑状态及 JavaScript 扩展。

## 本版本的主要改造

- 完成原生界面、权限说明、日期、时间、数字和单位的英文/简体中文本地化。
- 新增“港股与 A 股”扩展，支持 HKEX、SSE、SZSE 股票代码，并避开大陆行情接口。
- 新增“电脑状态”扩展，显示整机 CPU、内存、磁盘、SoC 温度、风扇转速、电源和热状态。
- 恢复紧凑模式横向切换，修复更新后只剩番茄钟、模块停止后仍被勾选等状态冲突。
- 优化股票紧凑视图：左侧显示 `HK990` 等市场代码，右侧显示单行实时价格，涨红跌绿，并保持原始紧凑宽度。
- 修复电脑状态刷新跳动、重复 CPU 采样、阴影闪烁和刘海收起回弹越界问题。
- 支持从“设置 -> 扩展”安装本地第三方扩展文件夹，安装前查看权限，并完整卸载扩展文件和数据。
- 新增可手动安装的“稍后提醒”扩展，支持一次性提醒、自定义分钟数、可选提示音、完成和延后十分钟。
- 天气模块支持“自动选择 / 和风天气 / Open-Meteo / 彩云天气”，中国大陆可优先使用和风天气，并显示 AQI、逐小时预报、高温等气象预警。
- 修复本地 arm64 DMG 构建的架构与临时签名问题。

## 系统要求

- macOS 14 Sonoma 或更高版本。
- 当前提供的 `v1.1.0` DMG 面向 Apple Silicon（M1/M2/M3/M4 等 arm64 Mac）。
- Intel Mac 请自行使用 `scripts/build-dmg-intel.sh` 构建；当前 Release 不包含 Intel 安装包。

## 下载与安装

1. 打开 [GitHub Releases](https://github.com/dearfaint/SuperIsland/releases)。
2. 下载 `SuperIsland-1.1.0-arm64.dmg`。
3. 打开 DMG，将 `SuperIsland.app` 拖入“应用程序”。
4. 完全退出旧版本后，从“应用程序”目录启动新版本。

当前 DMG 使用临时签名并且没有经过 Apple Developer ID 公证，因此发布为测试版。首次启动如果 macOS 阻止打开，请先在 Finder 中右键应用并选择“打开”；仍被阻止时，前往“系统设置 -> 隐私与安全性”确认打开。不要从不可信来源下载同名安装包。

## 语言切换

应用内没有独立语言开关，SuperIsland 跟随 macOS 的应用语言设置。

切换路径：

1. 打开“系统设置”。
2. 进入“通用 -> 语言与地区 -> 应用程序”。
3. 添加或选择 SuperIsland。
4. 选择“简体中文”或“English”。
5. 完全退出并重新打开 SuperIsland。

英文是源语言和回退语言。JavaScript 扩展可以通过语言映射提供本地化名称、设置项和运行时文本。

## 安装第三方扩展

1. 打开“设置 -> 扩展”。
2. 点击“安装扩展”，选择包含 `manifest.json` 和入口脚本的扩展文件夹。
3. 检查扩展名称、版本及申请的权限，然后确认安装。
4. 安装成功后扩展会立即启用，并显示“已安装”来源标签。

只有用户安装的扩展会显示“卸载”按钮。卸载会删除扩展文件及 `store`、设置等持久化数据；内置扩展只能停用，不能卸载。当前版本不接受 ZIP 扩展包，也不覆盖同 ID 扩展，请先解压并在需要替换时卸载旧版本。

仓库中的 [Nudge / 稍后提醒](InstallableExtensions/Nudge) 是可直接测试的第三方扩展。安装时选择整个 `InstallableExtensions/Nudge` 文件夹；打开完整面板后可选择快捷时间或输入自定义分钟数，再输入提醒内容并按 Return。提示音可在该扩展的设置中选择或填写自定义 macOS 声音名称。

## 港股与 A 股

在“设置 -> 扩展”中启用 **HK + A Stocks**，然后填写关注列表。

支持的代码格式：

- 港股：`HK:00990`、`HKEX:990`、`00990.HK`、`0990.HK`
- 上海 A 股：`SH:600519`、`SSE:600519`、`600519.SS`
- 深圳 A 股：`SZ:000001`、`SZSE:000001`、`000001.SZ`

行情来源：

- 主接口：TradingView Scanner（HKEX、SSE、SZSE）
- 备用接口：Yahoo Finance（`.HK`、`.SS`、`.SZ`）
- 不使用新浪、东方财富、腾讯财经、雪球等大陆行情接口

港股行情会根据交易所授权和上游可用性产生延迟，常见延迟约为 15 分钟。紧凑模式左侧使用 `HK990`、`SH600519` 等简写，右侧显示股票价格；上涨为红色，下跌为绿色。

## 电脑状态

在“设置 -> 扩展”中启用 **Computer Status**。该扩展通过原生只读接口提供：

- 整机 CPU 使用率与负载
- 活动监视器口径的已用内存、缓存文件和内存压力
- 用户主磁盘使用量
- Apple Silicon SoC 热点温度
- 风扇数量与当前 RPM
- 低电量模式、电源、系统热状态和运行时间

温度数据来自进程内只读 IOKit HID 传感器，风扇数据来自只读 AppleSMC。扩展不会修改风扇模式或目标转速，也不会读取进程列表、文件名或用户内容。

## 天气数据源

在“设置 -> 模块 -> 天气”中可以选择数据源：

- 自动选择：中国大陆优先使用已配置的和风天气，其他地区默认 Open-Meteo。
- 和风天气：使用 JWT 凭据，支持实时天气、逐小时预报、每日高低温、空气质量和气象预警。
- 彩云天气：支持 App Key / App Secret 签名请求，也保留旧 Token 请求作为备用。
- Open-Meteo：作为免费默认源和备用源，覆盖中国大陆以外地区。

预警会以图标显示在天气弹窗和主页天气温度附近，鼠标悬停可查看预警详情。

## 紧凑模式和模块启停

- 在紧凑岛上横向滑动可以循环切换可用模块。
- 股票紧凑视图保持原始宽度，避免遮挡菜单栏其他图标。
- 扩展启停以“设置 -> 扩展”为唯一入口。
- 菜单栏的“模块”菜单只管理内置模块，不再重复控制扩展。
- 停止当前扩展后，岛会立即切换到其他可用模块，不再保留无效勾选。

## 内置模块

SuperIsland 还包含以下主要功能：

- 正在播放：系统媒体、Apple Music、Spotify 和可选浏览器媒体检测
- 电池、天气、日历和通知
- 音量、亮度和键盘背光 HUD
- 专注模式、提词器和文件暂存架
- 番茄钟、AI 用量、Agents 状态、足球比分等扩展
- 普通、智能和低功耗后台刷新模式

部分功能需要在首次使用时授予辅助功能、日历、位置、麦克风或通知权限。未使用对应模块时无需授予无关权限。

## 本地构建

安装 Xcode、XcodeGen，并准备 Node.js 18+ 与 pnpm：

```bash
git clone git@github.com:dearfaint/SuperIsland.git
cd SuperIsland
xcodegen generate
open SuperIsland.xcodeproj
```

构建 Apple Silicon 本地 DMG：

```bash
./scripts/build-dmg.sh
```

产物位于 `build/SuperIsland.dmg`。没有开发者证书时脚本会执行临时签名，适合本机测试，不等同于 Developer ID 签名和 Apple 公证。

正式发布流程与环境变量要求见 [docs/RELEASE.md](docs/RELEASE.md)。

## 常见问题

### 应用程序或启动台出现多个 SuperIsland

Xcode 的 DerivedData 和临时构建目录也可能被 LaunchServices 索引。先确认正式安装位置只保留 `/Applications/SuperIsland.app`，然后删除本项目的构建缓存并刷新 Dock：

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SuperIsland-*
killall Dock
```

上述命令不会删除 SuperIsland 的用户设置，但会删除本项目的 Xcode 构建缓存。

### 安装后仍显示旧版本

完全退出菜单栏中的 SuperIsland，删除“应用程序”中的旧副本，再从 DMG 拖入新版本。不要直接从 Xcode DerivedData 或已挂载的 DMG 长期运行应用。

### 股票没有价格

检查代码格式和网络连接。TradingView 不可用时会尝试 Yahoo Finance；两者均不可用时扩展不会改用大陆行情接口。

## 开发文档

- [扩展开发说明](EXTENSIONS.md)
- [扩展 API](EXTENSIONS-API.md)
- [发布检查清单](docs/RELEASE.md)
- [架构说明](docs/architecture.md)
- [问题闭环记录](docs/issues.md)
- [开发路线图](docs/roadmap.md)

## 当前安装包校验

`SuperIsland-1.1.0-arm64.dmg`

```text
SHA-256: 3860d8933fad76a7d1268f2a40dcc32919c257620b18f816d2e9dcab784a49e0
```
