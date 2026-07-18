# Nudge / 稍后提醒

Nudge creates quick one-time reminders and keeps the next reminder visible on
SuperIsland. It is distributed as an installable extension rather than a
built-in module.

Nudge 用于快速创建一次性提醒，并在 SuperIsland 上持续显示最近一条提醒。它以可安装扩展
提供，不属于内置模块。

## Install / 安装

1. Open **Settings → Extensions** in SuperIsland.
2. Click **Install Extension**.
3. Select the entire `Nudge` folder and review the requested permissions.

1. 打开 SuperIsland 的**设置 → 扩展**。
2. 点击**安装扩展**。
3. 选择完整的 `Nudge` 文件夹，并确认权限。

## Use / 使用

Open Nudge's full view, choose a quick delay or enter a whole number from 1 to
1440 minutes and click **Set**, then type the reminder and press Return. Due
reminders can be completed or snoozed for ten minutes.

打开 Nudge 完整面板，先选择快捷时间，或输入 1 到 1440 的整数分钟数并点击**应用**，
再输入提醒内容并按 Return。提醒到期后可以完成，或延后十分钟。

## Alert sound / 提示音

Open Nudge in **Settings → Extensions** to choose the system default, a named
macOS sound, silence, or a custom sound name. Custom sound files can be placed
in `~/Library/Sounds`; enter the filename without its extension, then use
**Preview named or custom sound** to test it.

在**设置 → 扩展**中打开 Nudge，可以选择系统默认提示音、macOS 命名声音、静音，或输入
自定义声音名称。自定义声音文件可放入 `~/Library/Sounds`，填写不带扩展名的文件名后，
点击**试听命名或自定义提示音**进行测试。

## Permissions / 权限

- `storage`: saves reminders and restores them after the app restarts.
- `notifications`: sends a macOS notification when a reminder is due.
- `storage`：保存提醒，并在应用重启后恢复。
- `notifications`：提醒到期时发送 macOS 通知。

## Version 1 scope / 第一版边界

- Up to 10 one-time reminders, with complete and 10-minute snooze actions.
- No repeating reminders, system Calendar/Reminders integration, cloud sync, or
  accounts.
- SuperIsland must be running for an on-time alert. If the app was closed or
  the Mac was asleep, overdue reminders are delivered after it resumes.
- 最多保存 10 条一次性提醒，支持完成和延后 10 分钟。
- 不支持重复提醒、系统日历或提醒事项集成、云同步及账号。
- SuperIsland 需要保持运行才能准时提醒；如果应用已退出或 Mac 正在睡眠，恢复运行后会
  补发过期提醒。
