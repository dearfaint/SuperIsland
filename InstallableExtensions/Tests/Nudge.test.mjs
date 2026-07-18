import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const SCRIPT_URL = new URL("../Nudge/index.js", import.meta.url);
const BASE_NOW = Date.UTC(2026, 6, 16, 9, 0, 0);
const TEN_MINUTES = 10 * 60 * 1000;

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function createHarness(
  initialStore = {},
  initialSettings = {},
  namedSoundAvailable = true
) {
  let now = BASE_NOW;
  let moduleConfig = null;
  let nextTimerID = 1;
  const stored = new Map(
    Object.entries(initialStore).map(([key, value]) => [key, clone(value)])
  );
  const settings = new Map(
    Object.entries(initialSettings).map(([key, value]) => [key, clone(value)])
  );
  const intervals = new Map();
  const timeouts = new Map();
  const notifications = [];
  const playedSounds = [];
  const previewedSounds = [];
  const islandActivations = [];

  class FakeDate extends Date {
    constructor(...args) {
      super(...(args.length === 0 ? [now] : args));
    }

    static now() {
      return now;
    }
  }

  const View = new Proxy(
    {},
    {
      get(_target, property) {
        return (...args) => ({ type: String(property), args });
      }
    }
  );

  const SuperIsland = {
    registerModule(config) {
      moduleConfig = config;
    },
    store: {
      get(key) {
        return clone(stored.get(key));
      },
      set(key, value) {
        stored.set(key, clone(value));
      }
    },
    settings: {
      get(key) {
        return clone(settings.get(key));
      }
    },
    notifications: {
      send(options) {
        notifications.push(clone(options));
      },
      playSound(name) {
        playedSounds.push(name);
        return namedSoundAvailable;
      },
      previewSound(name) {
        previewedSounds.push(name);
        return namedSoundAvailable;
      }
    },
    island: {
      state: "compact",
      activate(animated) {
        islandActivations.push(animated);
      },
      dismiss() {}
    },
    mascot: {
      setExpression() {}
    },
    playFeedback() {}
  };

  function setIntervalMock(callback, milliseconds) {
    const id = nextTimerID++;
    intervals.set(id, { callback, milliseconds });
    return id;
  }

  function setTimeoutMock(callback, milliseconds) {
    const id = nextTimerID++;
    timeouts.set(id, { callback, fireAt: now + milliseconds });
    return id;
  }

  const context = vm.createContext({
    Date: FakeDate,
    Math,
    Number,
    Object,
    Array,
    String,
    Boolean,
    JSON,
    Intl,
    console,
    SuperIsland,
    View,
    setInterval: setIntervalMock,
    clearInterval(id) {
      intervals.delete(id);
    },
    setTimeout: setTimeoutMock,
    clearTimeout(id) {
      timeouts.delete(id);
    }
  });

  const source = readFileSync(SCRIPT_URL, "utf8");
  vm.runInContext(source, context, { filename: SCRIPT_URL.pathname });
  assert.ok(moduleConfig, "index.js must call SuperIsland.registerModule");

  return {
    module: moduleConfig,
    notifications,
    playedSounds,
    previewedSounds,
    islandActivations,
    getStore(key) {
      return clone(stored.get(key));
    },
    setNow(value) {
      now = value;
    },
    advance(milliseconds) {
      now += milliseconds;
    },
    runDueTimeouts() {
      for (const [id, timer] of [...timeouts.entries()]) {
        if (timer.fireAt > now) continue;
        timeouts.delete(id);
        timer.callback();
      }
    },
    initialize() {
      const hook = moduleConfig.onInit || moduleConfig.onActivate;
      assert.equal(
        typeof hook,
        "function",
        "the module must restore reminders during initialization"
      );
      hook();
    },
    refresh() {
      for (const { callback } of [...intervals.values()]) callback();
      for (const viewName of ["compact", "expanded", "fullExpanded"]) {
        if (typeof moduleConfig[viewName] === "function") moduleConfig[viewName]();
      }
    }
  };
}

function reminders(harness) {
  const value = harness.getStore("reminders");
  assert.ok(Array.isArray(value), "reminders must be stored as an array");
  return value;
}

function reminderFixture({
  id,
  title,
  dueAt,
  notifiedAt = null
}) {
  return { id, title, dueAt, notifiedAt };
}

function collectText(node, result = []) {
  if (Array.isArray(node)) {
    for (const child of node) collectText(child, result);
    return result;
  }
  if (!node || typeof node !== "object") return result;
  if (node.type === "text" && typeof node.args?.[0] === "string") {
    result.push(node.args[0]);
  }
  collectText(node.args, result);
  return result;
}

function findNode(node, predicate) {
  if (Array.isArray(node)) {
    for (const child of node) {
      const match = findNode(child, predicate);
      if (match) return match;
    }
    return null;
  }
  if (!node || typeof node !== "object") return null;
  if (predicate(node)) return node;
  return findNode(node.args, predicate);
}

test("creates a reminder with the selected absolute delay and persists both keys", () => {
  const harness = createHarness();
  harness.initialize();

  harness.module.onAction("select-delay:60");
  harness.module.onAction("create-reminder", "Call the dentist");

  assert.equal(harness.getStore("selectedDelayMinutes"), 60);
  const [created] = reminders(harness);
  assert.equal(created.title, "Call the dentist");
  assert.equal(created.dueAt, BASE_NOW + 60 * 60 * 1000);
  assert.equal(created.notifiedAt, null);
  assert.equal(typeof created.id, "string");
  assert.notEqual(created.id, "");
});

test("accepts and restores a custom whole-minute delay", () => {
  const harness = createHarness();
  harness.initialize();

  harness.module.onAction("set-custom-delay", "37");
  harness.module.onAction("create-reminder", "Check the download");

  assert.equal(harness.getStore("selectedDelayMinutes"), 37);
  assert.equal(reminders(harness)[0].dueAt, BASE_NOW + 37 * 60 * 1000);

  const restored = createHarness({
    reminders: [],
    selectedDelayMinutes: 37
  });
  restored.initialize();
  restored.module.onAction("create-reminder", "Restored custom delay");

  assert.equal(
    reminders(restored)[0].dueAt,
    BASE_NOW + 37 * 60 * 1000
  );
});

test("renders a compact custom delay input with an explicit apply action", () => {
  const harness = createHarness();
  harness.initialize();

  const view = harness.module.fullExpanded();
  const input = findNode(
    view,
    (node) => node.type === "inputBox" && node.args?.[2] === "set-custom-delay"
  );

  assert.ok(input, "the custom delay input should be present");
  assert.equal(input.args[3].minHeight, 30);
  assert.equal(input.args[3].compact, true);
  assert.deepEqual(
    clone(input.args[3].submitLabel),
    { en: "Set", "zh-Hans": "应用" }
  );
});

test("keeps a two-digit minimal countdown inside the compact trailing slot", () => {
  const harness = createHarness();
  harness.initialize();
  harness.module.onAction("create-reminder", "Compact countdown");
  harness.advance(18 * 60 * 1000);

  const trailing = harness.module.minimalCompact.trailing();
  const text = findNode(trailing, (node) => node.type === "text");

  assert.ok(text, "the minimal trailing slot should contain countdown text");
  assert.deepEqual(clone(text.args[0]), { en: "12m", "zh-Hans": "12分" });
  assert.equal(trailing.type, "frame");
  assert.equal(trailing.args[1].width, 34);
});

test("rejects invalid custom minute values without replacing the last valid delay", () => {
  const harness = createHarness();
  harness.initialize();

  for (const value of ["0", "-1", "1.5", "not-a-number", "1441"]) {
    harness.module.onAction("set-custom-delay", value);
  }

  assert.equal(harness.getStore("selectedDelayMinutes"), 30);

  harness.module.onAction("set-custom-delay", "1");
  assert.equal(harness.getStore("selectedDelayMinutes"), 1);
  harness.module.onAction("set-custom-delay", "1440");
  assert.equal(harness.getStore("selectedDelayMinutes"), 1440);
});

test("keeps no more than ten reminders", () => {
  const harness = createHarness();
  harness.initialize();

  for (let index = 1; index <= 11; index += 1) {
    harness.module.onAction("create-reminder", `Reminder ${index}`);
  }

  assert.equal(reminders(harness).length, 10);
});

test("notifies and activates the island once when a reminder becomes due", () => {
  const harness = createHarness();
  harness.initialize();
  harness.module.onAction("select-delay:10");
  harness.module.onAction("create-reminder", "Turn off the oven");

  const notificationCountBeforeDue = harness.notifications.length;
  const activationCountBeforeDue = harness.islandActivations.length;
  harness.advance(TEN_MINUTES);
  harness.runDueTimeouts();

  assert.equal(
    harness.notifications.length,
    notificationCountBeforeDue + 1,
    "a due reminder should send one notification"
  );
  assert.equal(
    harness.islandActivations.length,
    activationCountBeforeDue + 1,
    "a due reminder should activate the island"
  );
  assert.equal(harness.notifications.at(-1).sound, true);
  assert.deepEqual(harness.playedSounds, []);
  assert.equal(reminders(harness)[0].notifiedAt, BASE_NOW + TEN_MINUTES);

  harness.refresh();
  assert.equal(
    harness.notifications.length,
    notificationCountBeforeDue + 1,
    "refreshing again must not duplicate a due notification"
  );
  assert.equal(
    harness.islandActivations.length,
    activationCountBeforeDue + 1,
    "refreshing again must not reactivate for the same due reminder"
  );
});

test("plays the selected named or custom alert sound without duplicating notification audio", () => {
  const named = createHarness({}, { alertSound: "Funk" });
  named.initialize();
  named.module.onAction("select-delay:10");
  named.module.onAction("create-reminder", "Named sound");
  named.module.onAction("create-reminder", "Second named sound");
  named.advance(TEN_MINUTES);
  named.runDueTimeouts();

  assert.deepEqual(named.playedSounds, ["Funk"]);
  assert.equal(named.notifications.length, 2);
  assert.ok(named.notifications.every((notification) => notification.sound === false));

  const custom = createHarness({}, {
    alertSound: "custom",
    customSoundName: "My Reminder Sound"
  });
  custom.initialize();
  custom.module.onAction("select-delay:10");
  custom.module.onAction("create-reminder", "Custom sound");
  custom.advance(TEN_MINUTES);
  custom.runDueTimeouts();

  assert.deepEqual(custom.playedSounds, ["My Reminder Sound"]);
  assert.equal(custom.notifications[0].sound, false);
});

test("supports silent alerts and previews the selected named sound", () => {
  const silent = createHarness({}, { alertSound: "none" });
  silent.initialize();
  silent.module.onAction("select-delay:10");
  silent.module.onAction("create-reminder", "Silent sound");
  silent.advance(TEN_MINUTES);
  silent.runDueTimeouts();

  assert.deepEqual(silent.playedSounds, []);
  assert.equal(silent.notifications[0].sound, false);

  const preview = createHarness({}, { alertSound: "Ping" });
  preview.initialize();
  preview.module.onAction("preview-sound");
  assert.deepEqual(preview.previewedSounds, ["Ping"]);
  assert.deepEqual(preview.playedSounds, []);
});

test("falls back to the default notification sound when a named sound is unavailable", () => {
  const harness = createHarness(
    {},
    { alertSound: "custom", customSoundName: "Missing Sound" },
    false
  );
  harness.initialize();
  harness.module.onAction("select-delay:10");
  harness.module.onAction("create-reminder", "Fallback sound");
  harness.advance(TEN_MINUTES);
  harness.runDueTimeouts();

  assert.deepEqual(harness.playedSounds, ["Missing Sound"]);
  assert.equal(harness.notifications[0].sound, true);
});

test("snoozes a reminder for exactly ten minutes and clears notifiedAt", () => {
  const harness = createHarness();
  harness.initialize();
  harness.module.onAction("select-delay:10");
  harness.module.onAction("create-reminder", "Reply to the message");
  const id = reminders(harness)[0].id;

  harness.advance(TEN_MINUTES);
  harness.runDueTimeouts();
  harness.module.onAction(`snooze:${id}`);

  const [snoozed] = reminders(harness);
  assert.equal(snoozed.id, id);
  assert.equal(snoozed.dueAt, BASE_NOW + TEN_MINUTES * 2);
  assert.equal(snoozed.notifiedAt, null);
});

test("completes a reminder by removing it from persisted state", () => {
  const harness = createHarness();
  harness.initialize();
  harness.module.onAction("create-reminder", "Collect the laundry");
  const id = reminders(harness)[0].id;

  harness.module.onAction(`complete:${id}`);

  assert.deepEqual(reminders(harness), []);
});

test("restores absolute due times and presents reminders in due-time order", () => {
  const initialReminders = [
    reminderFixture({
      id: "later",
      title: "Later reminder",
      dueAt: BASE_NOW + 3 * 60 * 60 * 1000
    }),
    reminderFixture({
      id: "first",
      title: "First reminder",
      dueAt: BASE_NOW + 10 * 60 * 1000
    }),
    reminderFixture({
      id: "middle",
      title: "Middle reminder",
      dueAt: BASE_NOW + 60 * 60 * 1000
    })
  ];
  const harness = createHarness({
    reminders: initialReminders,
    selectedDelayMinutes: 30
  });

  harness.initialize();

  const view = harness.module.fullExpanded();
  const visibleText = collectText(view);
  assert.ok(
    visibleText.indexOf("First reminder") < visibleText.indexOf("Middle reminder"),
    "the earliest reminder should appear before the middle reminder"
  );
  assert.ok(
    visibleText.indexOf("Middle reminder") < visibleText.indexOf("Later reminder"),
    "the middle reminder should appear before the latest reminder"
  );
  assert.deepEqual(
    reminders(harness).map((reminder) => reminder.dueAt),
    [
      BASE_NOW + 10 * 60 * 1000,
      BASE_NOW + 60 * 60 * 1000,
      BASE_NOW + 3 * 60 * 60 * 1000
    ],
    "restored reminders should stay sorted in persisted state"
  );
});

test("delivers an overdue reminder once when the extension activates again", () => {
  const initial = reminderFixture({
    id: "overdue",
    title: "Overdue reminder",
    dueAt: BASE_NOW - TEN_MINUTES
  });
  const firstLaunch = createHarness({ reminders: [initial] });

  firstLaunch.initialize();

  assert.equal(firstLaunch.notifications.length, 1);
  assert.equal(reminders(firstLaunch)[0].notifiedAt, BASE_NOW);

  const secondLaunch = createHarness({
    reminders: reminders(firstLaunch),
    selectedDelayMinutes: 30
  });
  secondLaunch.initialize();

  assert.equal(secondLaunch.notifications.length, 0);
});
