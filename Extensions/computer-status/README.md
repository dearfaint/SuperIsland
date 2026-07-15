# Computer Status

Computer Status is a bundled SuperIsland extension for glanceable Mac health metrics.

It uses the host `system` permission and `SuperIsland.system.getComputerStatus()` to render whole-machine status. It does not launch `top`, `ps`, or a helper process.

- CPU usage and load average
- Activity Monitor-style memory used (`App + Wired + Compressed`) with cached files separated
- disk usage for the user's home volume
- Apple Silicon SoC hotspot temperature when HID die sensors are available
- read-only AppleSMC fan count and current RPM when available
- macOS thermal state, low-power state, and uptime

The temperature reader uses in-process, read-only IOKit HID sensor access and falls back to macOS thermal state when numeric sensors are unavailable. Fan status uses in-process, read-only AppleSMC access and never writes fan mode or target-speed keys. The snapshot does not expose process lists, sensor serials, file names, or user content.
