"use strict";

var MAX_REMINDERS = 10;
var DEFAULT_DELAY_MINUTES = 30;
var MIN_DELAY_MINUTES = 1;
var MAX_DELAY_MINUTES = 1440;
var SNOOZE_MINUTES = 10;
var ALLOWED_DELAYS = [10, 30, 60, 180];
var NAMED_ALERT_SOUNDS = {
  Glass: true,
  Funk: true,
  Pop: true,
  Basso: true,
  Ping: true
};

var reminders = [];
var selectedDelayMinutes = DEFAULT_DELAY_MINUTES;
var dueTimerID = null;
var scheduledDueAt = null;
var feedback = null;

var ACCENT = { r: 0.49, g: 0.36, b: 0.99, a: 1 };
var ACCENT_SOFT = { r: 0.49, g: 0.36, b: 0.99, a: 0.18 };
var DUE = { r: 1, g: 0.38, b: 0.28, a: 1 };
var MUTED = { r: 1, g: 1, b: 1, a: 0.48 };
var FAINT = { r: 1, g: 1, b: 1, a: 0.1 };

function localized(en, zhHans) {
  return { en: en, "zh-Hans": zhHans };
}

function normalizeDelayMinutes(value) {
  var minutes = Number(value);
  if (!Number.isFinite(minutes) || Math.floor(minutes) !== minutes) return null;
  if (minutes < MIN_DELAY_MINUTES || minutes > MAX_DELAY_MINUTES) return null;
  return minutes;
}

function isPresetDelay(value) {
  return ALLOWED_DELAYS.indexOf(value) !== -1;
}

function setSelectedDelay(value) {
  var minutes = normalizeDelayMinutes(value);
  if (minutes === null) return false;
  selectedDelayMinutes = minutes;
  SuperIsland.store.set("selectedDelayMinutes", selectedDelayMinutes);
  return true;
}

function normalizeReminder(value) {
  if (!value || typeof value !== "object") return null;

  var id = typeof value.id === "string" ? value.id.trim() : "";
  var title = typeof value.title === "string" ? value.title.trim() : "";
  var dueAt = Number(value.dueAt);
  var notifiedAt = value.notifiedAt === null || value.notifiedAt === undefined
    ? null
    : Number(value.notifiedAt);

  if (!id || !title || !Number.isFinite(dueAt) || dueAt <= 0) return null;
  if (notifiedAt !== null && !Number.isFinite(notifiedAt)) notifiedAt = null;

  return {
    id: id,
    title: title,
    dueAt: dueAt,
    notifiedAt: notifiedAt
  };
}

function sortReminders() {
  reminders.sort(function(lhs, rhs) {
    if (lhs.dueAt !== rhs.dueAt) return lhs.dueAt - rhs.dueAt;
    return lhs.id.localeCompare(rhs.id);
  });
}

function saveReminders() {
  sortReminders();
  SuperIsland.store.set("reminders", reminders);
}

function loadState() {
  var storedReminders = SuperIsland.store.get("reminders");
  reminders = Array.isArray(storedReminders)
    ? storedReminders.map(normalizeReminder).filter(Boolean)
    : [];
  sortReminders();
  reminders = reminders.slice(0, MAX_REMINDERS);

  var storedDelay = normalizeDelayMinutes(
    SuperIsland.store.get("selectedDelayMinutes")
  );
  selectedDelayMinutes = storedDelay === null
    ? DEFAULT_DELAY_MINUTES
    : storedDelay;

  saveReminders();
  SuperIsland.store.set("selectedDelayMinutes", selectedDelayMinutes);
}

function scheduleNextDueReminder() {
  var next = reminders.find(function(reminder) {
    return reminder.notifiedAt === null;
  });
  var nextDueAt = next ? next.dueAt : null;
  if (dueTimerID !== null && scheduledDueAt === nextDueAt) return;

  if (dueTimerID !== null) {
    clearTimeout(dueTimerID);
    dueTimerID = null;
  }
  scheduledDueAt = nextDueAt;
  if (!next) return;

  dueTimerID = setTimeout(function() {
    dueTimerID = null;
    scheduledDueAt = null;
    processDueReminders();
  }, Math.max(0, next.dueAt - Date.now()));
}

function settingString(key, fallback) {
  if (!SuperIsland.settings || typeof SuperIsland.settings.get !== "function") {
    return fallback;
  }
  var value = SuperIsland.settings.get(key);
  if (typeof value !== "string") return fallback;
  var normalized = value.trim();
  return normalized || fallback;
}

function alertSoundConfiguration() {
  var selection = settingString("alertSound", "system");
  if (selection === "none") {
    return { notificationSound: false, soundName: null };
  }
  if (selection === "custom") {
    return {
      notificationSound: false,
      soundName: settingString("customSoundName", "Ping")
    };
  }
  if (NAMED_ALERT_SOUNDS[selection] === true) {
    return { notificationSound: false, soundName: selection };
  }
  return { notificationSound: true, soundName: null };
}

function playNamedAlertSound(soundName) {
  if (!soundName) return false;
  if (SuperIsland.notifications &&
      typeof SuperIsland.notifications.playSound === "function") {
    return SuperIsland.notifications.playSound(soundName) !== false;
  }
  return false;
}

function previewAlertSound() {
  var sound = alertSoundConfiguration();
  if (!sound.soundName) return;
  if (SuperIsland.notifications &&
      typeof SuperIsland.notifications.previewSound === "function") {
    SuperIsland.notifications.previewSound(sound.soundName);
    return;
  }
  playNamedAlertSound(sound.soundName);
}

function sendDueNotification(reminder, shouldPlaySound) {
  var sound = shouldPlaySound
    ? alertSoundConfiguration()
    : { notificationSound: false, soundName: null };
  var playedNamedSound = shouldPlaySound && playNamedAlertSound(sound.soundName);
  SuperIsland.notifications.send({
    title: "Nudge",
    body: reminder.title,
    sound: sound.notificationSound || (sound.soundName !== null && !playedNamedSound)
  });
}

function processDueReminders() {
  var now = Date.now();
  var due = reminders.filter(function(reminder) {
    return reminder.notifiedAt === null && reminder.dueAt <= now;
  });

  if (due.length === 0) {
    scheduleNextDueReminder();
    return;
  }

  due.forEach(function(reminder) {
    reminder.notifiedAt = now;
  });
  saveReminders();

  due.forEach(function(reminder, index) {
    sendDueNotification(reminder, index === 0);
  });
  SuperIsland.island.activate(false);
  scheduleNextDueReminder();
}

function createReminder(title) {
  var normalizedTitle = String(title || "").trim();
  if (!normalizedTitle) return;

  if (reminders.length >= MAX_REMINDERS) {
    feedback = {
      text: localized("You can keep up to 10 reminders.", "最多只能保存 10 条提醒。"),
      color: DUE,
      until: Date.now() + 3000
    };
    SuperIsland.playFeedback("error");
    return;
  }

  var now = Date.now();
  var reminder = {
    id: "nudge-" + now.toString(36) + "-" + Math.floor(Math.random() * 100000).toString(36),
    title: normalizedTitle,
    dueAt: now + selectedDelayMinutes * 60 * 1000,
    notifiedAt: null
  };

  reminders.push(reminder);
  saveReminders();
  scheduleNextDueReminder();
  feedback = {
    text: localized(
      "Reminder added for " + selectedDelayMinutes + " minutes.",
      "已添加 " + selectedDelayMinutes + " 分钟后的提醒。"
    ),
    color: ACCENT,
    until: now + 2500
  };
  SuperIsland.playFeedback("success");
}

function completeReminder(reminderID) {
  var completed = reminders.find(function(reminder) {
    return reminder.id === reminderID;
  });
  if (!completed) return;
  var wasDue = isDue(completed);

  reminders = reminders.filter(function(reminder) {
    return reminder.id !== reminderID;
  });

  saveReminders();
  scheduleNextDueReminder();
  SuperIsland.playFeedback("success");

  if (wasDue && !hasDueReminder()) SuperIsland.island.dismiss();
}

function snoozeReminder(reminderID) {
  var reminder = reminders.find(function(candidate) {
    return candidate.id === reminderID;
  });
  if (!reminder) return;

  reminder.dueAt = Date.now() + SNOOZE_MINUTES * 60 * 1000;
  reminder.notifiedAt = null;
  saveReminders();
  scheduleNextDueReminder();
  SuperIsland.playFeedback("selection");
  if (!hasDueReminder()) SuperIsland.island.dismiss();
}

function hasDueReminder() {
  var now = Date.now();
  return reminders.some(function(reminder) {
    return reminder.dueAt <= now;
  });
}

function primaryReminder() {
  var now = Date.now();
  return reminders.find(function(reminder) {
    return reminder.dueAt <= now;
  }) || reminders[0] || null;
}

function isDue(reminder) {
  return reminder && reminder.dueAt <= Date.now();
}

function formatClock(timestamp) {
  return new Date(timestamp).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit"
  });
}

function countdownStrings(reminder, compact) {
  var seconds = Math.max(0, Math.ceil((reminder.dueAt - Date.now()) / 1000));
  if (seconds <= 0) return { en: "Now", zhHans: "现在" };
  if (seconds < 60) return { en: seconds + "s", zhHans: seconds + "秒" };

  var minutes = Math.ceil(seconds / 60);
  if (minutes < 60) {
    return {
      en: minutes + "m",
      zhHans: minutes + (compact ? "分" : "分钟")
    };
  }

  var hours = Math.floor(minutes / 60);
  var remainingMinutes = minutes % 60;
  if (compact) {
    return { en: hours + "h", zhHans: hours + "时" };
  }
  if (remainingMinutes === 0) {
    return { en: hours + "h", zhHans: hours + "小时" };
  }
  return {
    en: hours + "h " + remainingMinutes + "m",
    zhHans: hours + "小时" + remainingMinutes + "分钟"
  };
}

function countdownText(reminder, compact) {
  var value = countdownStrings(reminder, compact);
  return localized(value.en, value.zhHans);
}

function detailText(reminder) {
  if (isDue(reminder)) return localized("Due now", "现在到期");

  var countdown = countdownStrings(reminder, false);
  return localized(
    "In " + countdown.en + " · " + formatClock(reminder.dueAt),
    countdown.zhHans + "后 · " + formatClock(reminder.dueAt)
  );
}

function reminderIcon(reminder) {
  return isDue(reminder) ? "bell.badge.fill" : "bell.fill";
}

function reminderColor(reminder) {
  return isDue(reminder) ? DUE : ACCENT;
}

function textButton(label, actionID, color) {
  return View.button(
    View.cornerRadius(
      View.background(
        View.padding(
          View.text(label, { style: "caption", color: color || "white", lineLimit: 1 }),
          { edges: "all", amount: 5 }
        ),
        FAINT
      ),
      8
    ),
    actionID
  );
}

function delayChip(minutes) {
  var active = selectedDelayMinutes === minutes;
  var label = minutes < 60 ? minutes + "m" : minutes / 60 + "h";
  return View.button(
    View.cornerRadius(
      View.background(
        View.padding(
          View.hstack([
            active ? View.icon("checkmark", { size: 9, color: "white" }) : null,
            View.text(label, {
              style: "caption",
              color: active ? "white" : MUTED,
              lineLimit: 1
            })
          ], { spacing: 3, align: "center" }),
          { edges: "all", amount: 5 }
        ),
        active ? ACCENT_SOFT : FAINT
      ),
      8
    ),
    "select-delay:" + minutes
  );
}

function customDelayControl() {
  var active = !isPresetDelay(selectedDelayMinutes);
  var placeholder = active
    ? localized(selectedDelayMinutes + "m", selectedDelayMinutes + " 分钟")
    : localized("Minutes", "分钟数");

  return View.hstack([
    View.hstack([
      active ? View.icon("checkmark", { size: 9, color: "white" }) : null,
      View.text(localized("Custom", "自定义"), {
        style: "footnote",
        color: active ? "white" : MUTED,
        lineLimit: 1
      })
    ], { spacing: 3, align: "center" }),
    View.frame(
      View.inputBox(
        placeholder,
        "",
        "set-custom-delay",
        {
          id: "nudge-delay-input-" + selectedDelayMinutes,
          autoFocus: false,
          minHeight: 30,
          showsEmojiButton: false,
          compact: true,
          submitLabel: localized("Set", "应用")
        }
      ),
      { width: 110, height: 30, alignment: "center" }
    )
  ], { spacing: 5, align: "center" });
}

function reminderRow(reminder) {
  var due = isDue(reminder);
  var actions = [];
  if (due) {
    actions.push(textButton(
      localized("Snooze 10m", "延后10分"),
      "snooze:" + reminder.id,
      ACCENT
    ));
  }
  actions.push(textButton(localized("Done", "完成"), "complete:" + reminder.id, MUTED));

  return View.hstack([
    View.icon(reminderIcon(reminder), { size: 13, color: reminderColor(reminder) }),
    View.frame(
      View.vstack([
        View.text(reminder.title, { style: "caption", color: "white", lineLimit: 1 }),
        View.text(detailText(reminder), {
          style: "footnote",
          color: due ? DUE : MUTED,
          lineLimit: 1
        })
      ], { spacing: 1, align: "leading" }),
      { maxWidth: 9999, alignment: "leading" }
    )
  ].concat(actions), { spacing: 6, align: "center" });
}

function compactView() {
  processDueReminders();
  var reminder = primaryReminder();
  if (!reminder) {
    return View.hstack([
      View.icon("bell", { size: 12, color: MUTED }),
      View.text(localized("Add a reminder", "添加提醒"), {
        style: "caption",
        color: MUTED,
        lineLimit: 1
      })
    ], { spacing: 6, align: "center" });
  }

  return View.hstack([
    View.icon(reminderIcon(reminder), { size: 12, color: reminderColor(reminder) }),
    View.text(reminder.title, { style: "caption", color: "white", lineLimit: 1 }),
    View.spacer(),
    View.text(countdownText(reminder, true), {
      style: "monospacedSmall",
      color: reminderColor(reminder),
      lineLimit: 1
    })
  ], { spacing: 6, align: "center" });
}

function expandedView() {
  processDueReminders();
  var reminder = primaryReminder();
  if (!reminder) {
    return View.hstack([
      View.icon("bell.badge", { size: 22, color: ACCENT }),
      View.vstack([
        View.text(localized("No reminders", "暂无提醒"), {
          style: "title",
          color: "white",
          lineLimit: 1
        }),
        View.text(localized("Open the full view to add one.", "打开完整面板即可添加。"), {
          style: "caption",
          color: MUTED,
          lineLimit: 1
        })
      ], { spacing: 2, align: "leading" })
    ], { spacing: 10, align: "center" });
  }

  var due = isDue(reminder);
  var actions = [];
  if (due) {
    actions.push(textButton(localized("Snooze", "延后"), "snooze:" + reminder.id, ACCENT));
  }
  actions.push(textButton(localized("Done", "完成"), "complete:" + reminder.id, MUTED));

  return View.hstack([
    View.icon(reminderIcon(reminder), { size: 22, color: reminderColor(reminder) }),
    View.frame(
      View.vstack([
        View.text(reminder.title, { style: "title", color: "white", lineLimit: 1 }),
        View.text(detailText(reminder), {
          style: "caption",
          color: due ? DUE : MUTED,
          lineLimit: 1
        })
      ], { spacing: 2, align: "leading" }),
      { maxWidth: 9999, alignment: "leading" }
    )
  ].concat(actions), { spacing: 8, align: "center" });
}

function fullExpandedView() {
  processDueReminders();

  var feedbackNode = feedback && feedback.until > Date.now()
    ? View.text(feedback.text, {
        style: "footnote",
        color: feedback.color,
        lineLimit: 1
      })
    : null;

  var reminderList = reminders.length > 0
    ? View.scroll(
        View.vstack(reminders.map(reminderRow), { spacing: 7, align: "leading" }),
        { axes: "vertical", showsIndicators: reminders.length > 3 }
      )
    : View.frame(
        View.text(localized(
          "Your reminders will appear here.",
          "新建的提醒会显示在这里。"
        ), { style: "caption", color: MUTED, lineLimit: 1 }),
        { maxWidth: 9999, maxHeight: 9999, alignment: "center" }
      );
  var inputNode = reminders.length >= MAX_REMINDERS
    ? View.frame(
        View.text(localized(
          "10-reminder limit reached. Complete one to add another.",
          "已达到 10 条上限，请先完成一条提醒。"
        ), { style: "caption", color: DUE, lineLimit: 2 }),
        { maxWidth: 9999, height: 46, alignment: "center" }
      )
    : View.inputBox(
        localized(
          "Type a reminder, then press Return",
          "输入提醒，按 Return 添加"
        ),
        "",
        "create-reminder",
        {
          id: "nudge-reminder-input",
          autoFocus: reminders.length === 0,
          minHeight: 46,
          showsEmojiButton: false
        }
      );

  return View.vstack([
    View.hstack([
      View.text(localized("New reminder", "新建提醒"), {
        style: "title",
        color: "white",
        lineLimit: 1
      }),
      View.spacer(),
      View.text(localized(
        reminders.length + " of " + MAX_REMINDERS,
        reminders.length + " / " + MAX_REMINDERS
      ), { style: "footnote", color: MUTED, lineLimit: 1 })
    ], { spacing: 6, align: "center" }),
    View.hstack([
      View.hstack(ALLOWED_DELAYS.map(delayChip), { spacing: 6, align: "center" }),
      View.spacer(),
      customDelayControl()
    ], { spacing: 6, align: "center" }),
    inputNode,
    feedbackNode,
    View.divider(),
    View.frame(reminderList, { maxWidth: 9999, maxHeight: 9999, alignment: "top" })
  ], { spacing: 6, align: "leading" });
}

SuperIsland.registerModule({
  onActivate: function() {
    loadState();
    processDueReminders();
  },

  onDeactivate: function() {
    if (dueTimerID !== null) {
      clearTimeout(dueTimerID);
      dueTimerID = null;
    }
    scheduledDueAt = null;
  },

  onAction: function(actionID, value) {
    if (actionID.indexOf("select-delay:") === 0) {
      var minutes = Number(actionID.slice("select-delay:".length));
      if (isPresetDelay(minutes) && setSelectedDelay(minutes)) {
        SuperIsland.playFeedback("selection");
      }
      return;
    }

    if (actionID === "set-custom-delay") {
      if (setSelectedDelay(value)) {
        feedback = {
          text: localized(
            "Time set to " + selectedDelayMinutes + " minutes.",
            "提醒时间已设为 " + selectedDelayMinutes + " 分钟。"
          ),
          color: ACCENT,
          until: Date.now() + 2500
        };
        SuperIsland.playFeedback("selection");
      } else {
        feedback = {
          text: localized(
            "Enter a whole number from 1 to 1440 minutes.",
            "请输入 1 到 1440 的整数分钟数。"
          ),
          color: DUE,
          until: Date.now() + 3000
        };
        SuperIsland.playFeedback("error");
      }
      return;
    }

    if (actionID === "preview-sound") {
      previewAlertSound();
      return;
    }

    if (actionID === "create-reminder") {
      createReminder(value);
      return;
    }

    if (actionID.indexOf("complete:") === 0) {
      completeReminder(actionID.slice("complete:".length));
      return;
    }

    if (actionID.indexOf("snooze:") === 0) {
      snoozeReminder(actionID.slice("snooze:".length));
    }
  },

  compact: compactView,

  minimalCompact: {
    leading: function() {
      processDueReminders();
      var reminder = primaryReminder();
      return View.frame(
        View.icon(reminder ? reminderIcon(reminder) : "bell", {
          size: 12,
          color: reminder ? reminderColor(reminder) : MUTED
        }),
        { width: 22, height: 22, alignment: "center" }
      );
    },
    trailing: function() {
      var reminder = primaryReminder();
      return View.frame(
        View.text(reminder ? countdownText(reminder, true) : "--", {
          style: "monospacedSmall",
          color: reminder ? reminderColor(reminder) : MUTED,
          lineLimit: 1
        }),
        { width: 34, height: 22, alignment: "trailing" }
      );
    },
    precedence: function() {
      var reminder = primaryReminder();
      if (!reminder) return 0;
      return isDue(reminder) ? 3 : 1;
    }
  },

  expanded: expandedView,
  fullExpanded: fullExpandedView
});
