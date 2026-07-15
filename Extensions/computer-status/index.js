"use strict";

const EMPTY_STATUS = {
  cpu: {
    usagePercent: 0,
    userPercent: 0,
    systemPercent: 0,
    coreCount: 0,
    activeCoreCount: 0,
    loadAverage: []
  },
  memory: {
    totalBytes: 0,
    usedBytes: 0,
    appBytes: 0,
    wiredBytes: 0,
    compressedBytes: 0,
    cachedBytes: 0,
    availableBytes: 0,
    freeBytes: 0,
    usagePercent: 0
  },
  disk: { totalBytes: 0, usedBytes: 0, freeBytes: 0, usagePercent: 0 },
  temperature: { available: false },
  fans: { available: false, count: 0, items: [] },
  power: { thermalState: "unknown", lowPowerMode: false, uptimeSeconds: 0 }
};

const LABELS = {
  memory: { en: "Memory", "zh-Hans": "内存" },
  disk: { en: "Disk", "zh-Hans": "磁盘" },
  temperature: { en: "SoC Temp", "zh-Hans": "芯片温度" },
  fan: { en: "Fan", "zh-Hans": "风扇" },
  fanless: { en: "Fanless", "zh-Hans": "无风扇" },
  lowPower: { en: "Low Power", "zh-Hans": "低电量模式" }
};

function asObject(value, fallback) {
  return value && typeof value === "object" ? value : fallback;
}

function snapshot() {
  if (!SuperIsland.system || typeof SuperIsland.system.getComputerStatus !== "function") {
    return EMPTY_STATUS;
  }
  return asObject(SuperIsland.system.getComputerStatus(), EMPTY_STATUS);
}

function clamp(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return min;
  return Math.max(min, Math.min(max, number));
}

function ratio(value) {
  return clamp(value, 0, 100) / 100;
}

function percent(value) {
  return `${Math.round(clamp(value, 0, 100))}%`;
}

function bytes(value) {
  const safe = Math.max(0, Number(value) || 0);
  if (safe >= 1024 * 1024 * 1024 * 1024) {
    return `${(safe / (1024 * 1024 * 1024 * 1024)).toFixed(1)} TB`;
  }
  if (safe >= 1024 * 1024 * 1024) {
    return `${(safe / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }
  if (safe >= 1024 * 1024) {
    return `${Math.round(safe / (1024 * 1024))} MB`;
  }
  return `${Math.round(safe / 1024)} KB`;
}

function uptime(seconds) {
  const hours = Math.floor(Math.max(0, Number(seconds) || 0) / 3600);
  if (hours >= 48) {
    const days = Math.round(hours / 24);
    return { en: `Uptime ${days}d`, "zh-Hans": `已运行 ${days}天` };
  }
  return { en: `Uptime ${hours}h`, "zh-Hans": `已运行 ${hours}小时` };
}

function colorFor(value) {
  const safe = clamp(value, 0, 100);
  if (safe >= 90) return "red";
  if (safe >= 75) return "orange";
  if (safe >= 55) return "yellow";
  return "green";
}

function thermalColor(state) {
  switch (state) {
    case "critical": return "red";
    case "serious": return "orange";
    case "fair": return "yellow";
    case "nominal": return "green";
    default: return "gray";
  }
}

function temperatureValue(temperature) {
  if (!temperature || temperature.available !== true) return "--";
  return `${Math.round(Number(temperature.socCelsius) || 0)}°`;
}

function temperatureProgress(temperature, thermalState) {
  if (temperature && temperature.available === true) {
    return clamp(((Number(temperature.socCelsius) || 30) - 30) / 0.7, 0, 100);
  }
  switch (thermalState) {
    case "critical": return 100;
    case "serious": return 85;
    case "fair": return 65;
    case "nominal": return 35;
    default: return 0;
  }
}

function temperatureColor(temperature, thermalState) {
  if (!temperature || temperature.available !== true) return thermalColor(thermalState);
  const value = Number(temperature.socCelsius) || 0;
  if (value >= 100) return "red";
  if (value >= 85) return "orange";
  if (value >= 70) return "yellow";
  return "green";
}

function fanMetric(fans) {
  const data = asObject(fans, EMPTY_STATUS.fans);
  if (data.available !== true) {
    return { value: "--", label: LABELS.fan, progress: 0, color: "gray" };
  }

  const count = Math.max(0, Math.round(Number(data.count) || 0));
  if (count === 0) {
    return { value: "0", label: LABELS.fanless, progress: 0, color: "gray" };
  }

  const items = Array.isArray(data.items) ? data.items : [];
  const readings = items
    .map((item) => ({
      actual: Number(item && item.actualRPM),
      maximum: Number(item && item.maximumRPM)
    }))
    .filter((item) => Number.isFinite(item.actual) && item.actual >= 0);

  if (readings.length === 0) {
    return { value: "--", label: LABELS.fan, progress: 0, color: "gray" };
  }

  const progress = readings.reduce((highest, item) => {
    if (!Number.isFinite(item.maximum) || item.maximum <= 0) return highest;
    return Math.max(highest, clamp(item.actual / item.maximum * 100, 0, 100));
  }, 0);
  return {
    value: readings.map((item) => Math.round(item.actual)).join("/"),
    label: LABELS.fan,
    progress,
    color: progress > 0 ? colorFor(progress) : "cyan"
  };
}

function compactStat(icon, value, color, width) {
  return View.frame(
    View.hstack([
      View.icon(icon, { size: 11, color }),
      View.text(value, { style: "monospacedSmall", color, lineLimit: 1 })
    ], { spacing: 3, align: "center" }),
    { width: width || 58, alignment: "center" }
  );
}

function minimalStat(icon, value, color, side) {
  const stat = compactStat(icon, value, color, 48);
  return side === "leading"
    ? View.hstack([View.spacer(), stat], { spacing: 0, align: "center" })
    : View.hstack([stat, View.spacer()], { spacing: 0, align: "center" });
}

function ringMetric(icon, label, value, progress, color, width) {
  return View.frame(
    View.vstack([
      View.zstack([
        View.circularProgress(ratio(progress), { total: 1, lineWidth: 6, color }),
        View.icon(icon, { size: 9, color })
      ]),
      View.text(value, { style: "monospacedSmall", color: "white", lineLimit: 1 }),
      View.text(label, { style: "footnote", color: "gray", lineLimit: 1 })
    ], { spacing: 2, align: "center" }),
    { width: width || 82, height: 64, alignment: "center" }
  );
}

function metricRow(data, includeFan) {
  const thermalState = data.power.thermalState || "unknown";
  const width = includeFan ? 66 : 82;
  const metrics = [
    ringMetric("cpu", "CPU", percent(data.cpu.usagePercent), data.cpu.usagePercent, colorFor(data.cpu.usagePercent), width),
    ringMetric("memorychip", LABELS.memory, percent(data.memory.usagePercent), data.memory.usagePercent, colorFor(data.memory.usagePercent), width),
    ringMetric("internaldrive", LABELS.disk, percent(data.disk.usagePercent), data.disk.usagePercent, colorFor(data.disk.usagePercent), width),
    ringMetric(
      "thermometer.medium",
      LABELS.temperature,
      temperatureValue(data.temperature),
      temperatureProgress(data.temperature, thermalState),
      temperatureColor(data.temperature, thermalState),
      width
    )
  ];

  if (includeFan) {
    const fan = fanMetric(data.fans);
    metrics.push(ringMetric("fan", fan.label, fan.value, fan.progress, fan.color, width));
  }

  return View.hstack(metrics, {
    spacing: includeFan ? 3 : 6,
    align: "center",
    distribution: "fillEqually"
  });
}

SuperIsland.registerModule({
  compact() {
    const data = snapshot();
    const thermalState = data.power.thermalState || "unknown";
    return View.hstack([
      compactStat("cpu", percent(data.cpu.usagePercent), colorFor(data.cpu.usagePercent)),
      compactStat("memorychip", percent(data.memory.usagePercent), colorFor(data.memory.usagePercent)),
      compactStat("thermometer.medium", temperatureValue(data.temperature), temperatureColor(data.temperature, thermalState))
    ], { spacing: 4, align: "center", distribution: "fillEqually" });
  },

  minimalCompact: {
    leading() {
      const data = snapshot();
      return minimalStat("cpu", percent(data.cpu.usagePercent), colorFor(data.cpu.usagePercent), "leading");
    },

    trailing() {
      const data = snapshot();
      const thermalState = data.power.thermalState || "unknown";
      return minimalStat(
        "thermometer.medium",
        temperatureValue(data.temperature),
        temperatureColor(data.temperature, thermalState),
        "trailing"
      );
    },

    precedence: 1
  },

  expanded() {
    return View.frame(metricRow(snapshot(), false), { maxWidth: 1000, height: 68, alignment: "center" });
  },

  fullExpanded() {
    const data = snapshot();
    const load = Array.isArray(data.cpu.loadAverage) && data.cpu.loadAverage.length > 0
      ? data.cpu.loadAverage.join(" / ")
      : "--";
    const thermalState = data.power.thermalState || "unknown";
    const details = `Load ${load} · Memory ${bytes(data.memory.usedBytes)} / ${bytes(data.memory.totalBytes)} · Disk ${bytes(data.disk.freeBytes)} free`;

    return View.vstack([
      View.hstack([
        View.spacer(),
        View.icon("thermometer.medium", { size: 11, color: thermalColor(thermalState) }),
        View.text(
          data.power.lowPowerMode ? LABELS.lowPower : uptime(data.power.uptimeSeconds),
          { style: "monospacedSmall", color: "gray", lineLimit: 1 }
        )
      ], { spacing: 5, align: "center" }),
      metricRow(data, true),
      View.frame(
        View.text(details, { style: "footnote", color: "gray", lineLimit: 1 }),
        { maxWidth: 1000, height: 14, alignment: "center" }
      )
    ], { spacing: 6, align: "leading" });
  }
});
