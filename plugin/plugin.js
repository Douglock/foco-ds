/**
 * Foco DS — Super Productivity Integration Plugin
 * Real-time active task and habits sync.
 */

const FOCO_DS_BRIDGE_URL = "http://127.0.0.1:28475";
const SYNC_INTERVAL_MS = 500;

const emojiRegex = /(\p{Extended_Pictographic}|\p{Emoji_Presentation})/u;

const MATERIAL_ICON_EMOJI_MAP = {
  local_cafe: "☕",
  coffee: "☕",
  free_breakfast: "☕",
  water_drop: "🥤",
  water: "🥤",
  opacity: "💧",
  fitness_center: "🏋️",
  fitness: "🏋️",
  directions_walk: "🚶",
  walk: "🚶",
  menu_book: "📚",
  book: "📚",
  self_improvement: "🧎",
  sports: "🏋️",
};

function extractEmojiForHabit(counter) {
  if (!counter) return "⭐";
  const iconStr = String(counter.icon || "").trim();
  const iconMatch = iconStr.match(emojiRegex);
  if (iconMatch) return iconMatch[0];

  const titleStr = String(counter.title || "").trim();
  const titleMatch = titleStr.match(emojiRegex);
  if (titleMatch) return titleMatch[0];

  const cleanIcon = iconStr.toLowerCase().replace(/^:/, "").replace(/[^a-z0-9_]/g, "");
  if (MATERIAL_ICON_EMOJI_MAP[cleanIcon]) return MATERIAL_ICON_EMOJI_MAP[cleanIcon];

  const lowerTitle = titleStr.toLowerCase();
  if (/(\bcafe\b|\bcafé\b|\bcoffee\b)/i.test(lowerTitle)) return "☕";
  if (/(\bagua\b|\bágua\b|\bwater\b|\bhidrata|\bbeber\b)/i.test(lowerTitle)) return "🥤";
  if (/(\btreino\b|\bgym\b|\bmusculacao\b|\bfitness|\bexercicio\b)/i.test(lowerTitle)) return "🏋️";
  if (/(\bler\b|\bleitura\b|\blivro\b|\bbook\b|\bread\b|\bobsidian\b)/i.test(lowerTitle)) return "📚";
  if (/(\balong|alongamento|desaquecimento)/i.test(lowerTitle)) return "🧎";
  if (/(\bsono\b|\bsleep\b|\bdormir\b)/i.test(lowerTitle)) return "🌙";
  if (/(\bmedit|mindfulness)/i.test(lowerTitle)) return "🧘";
  if (/(\bremedio|remedio|pill|vitamina)/i.test(lowerTitle)) return "💊";
  return "⭐";
}

function getTodayStr() {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// Global runtime state
const state = {
  running: false,
  activeTaskId: null,
};

let lastPayloadString = "";
let previousIsBreak = false;
let previousRemaining = 0;
let isSyncing = false;
let wasTracking = false;
let previousTrackedTaskId = null;
const alertedOvertimeMap = new Set();

async function syncState() {
  if (isSyncing) return;
  isSyncing = true;

  try {
    let activeTask = null;
    let isBreak = false;
    let remainingSeconds = 0;
    let focusDurationSeconds = 25 * 60;
    let mappedHabits = [];
    let allTasks = [];
    let appState = null;

    if (typeof PluginAPI !== "undefined") {
      // 1. Fetch appState
      if (typeof PluginAPI.getAppState === "function") {
        try {
          appState = await PluginAPI.getAppState();
        } catch (e) {}
      }

      // 2. Fetch Tasks list
      try {
        if (typeof PluginAPI.getTasks === "function") {
          const list = await PluginAPI.getTasks();
          if (Array.isArray(list) && list.length > 0) allTasks = list;
        }
      } catch (e) {}

      if (allTasks.length === 0 && typeof PluginAPI.getCurrentContextTasks === "function") {
        try {
          const ctxList = await PluginAPI.getCurrentContextTasks();
          if (Array.isArray(ctxList) && ctxList.length > 0) allTasks = ctxList;
        } catch (e) {}
      }

      // Merge entities from appState if needed
      const taskStore = appState?.tasks || appState?.task || appState?.TASK || appState?.TASKS;
      if (allTasks.length === 0 && taskStore?.entities) {
        allTasks = Object.values(taskStore.entities).filter(Boolean);
      }

      // 3. Resolve active currentTaskId
      const currentTaskId =
        state.activeTaskId ||
        appState?.task?.currentTaskId ||
        appState?.tasks?.currentTaskId ||
        taskStore?.currentTaskId ||
        null;

      if (currentTaskId) {
        activeTask = allTasks.find(t => String(t.id) === String(currentTaskId));
        if (!activeTask && taskStore?.entities && taskStore.entities[currentTaskId]) {
          activeTask = taskStore.entities[currentTaskId];
        }
      }

      // Fallback: check getSelectedTask
      if (!activeTask && state.running && typeof PluginAPI.getSelectedTask === "function") {
        try {
          const selected = await PluginAPI.getSelectedTask();
          if (selected && selected.id) {
            activeTask = selected;
            state.activeTaskId = String(selected.id);
          }
        } catch (e) {}
      }

      // Check if time is tracking
      const isTimeTracking = Boolean(
        state.running ||
        appState?.timeTracking?.isTracking ||
        (appState?.task && appState.task.currentTaskId) ||
        (appState?.tasks && appState.tasks.currentTaskId)
      );

      // Pomodoro timing & break
      isBreak = Boolean(appState?.pomodoro?.isBreak);
      if (appState?.pomodoro) {
        if (typeof appState.pomodoro.currentCycleDuration === "number") {
          focusDurationSeconds = Math.round(appState.pomodoro.currentCycleDuration / 1000);
        }
        if (typeof appState.pomodoro.sessionRemaining === "number") {
          remainingSeconds = Math.round(appState.pomodoro.sessionRemaining / 1000);
        }
      }

      // Extract Habits (Simple Counters)
      const todayStr = getTodayStr();
      const rawCounters = appState?.simpleCounters ? Object.values(appState.simpleCounters) : [];
      if (rawCounters.length > 0) {
        mappedHabits = rawCounters
          .filter(c => c && c.isEnabled !== false)
          .map(c => ({
            id: String(c.id),
            title: String(c.title || ""),
            emoji: extractEmojiForHabit(c),
            count: Number(c.countOnDay?.[todayStr] || c.valueOnDay?.[todayStr] || 0),
            isOn: Boolean(c.isOn)
          }));
      } else if (typeof PluginAPI.getAllSimpleCounters === "function") {
        try {
          const counters = await PluginAPI.getAllSimpleCounters();
          if (Array.isArray(counters)) {
            mappedHabits = counters
              .filter(c => c && c.isEnabled !== false)
              .map(c => ({
                id: String(c.id),
                title: String(c.title || ""),
                emoji: extractEmojiForHabit(c),
                count: Number(c.countOnDay?.[todayStr] || c.valueOnDay?.[todayStr] || 0),
                isOn: Boolean(c.isOn)
              }));
          }
        } catch (e) {}
      }
    }

    const isTracking = Boolean(activeTask && (state.running || appState?.timeTracking?.isTracking || activeTask.isCurrent));

    // Detect PLAY (Transition from not tracking to tracking, or switching to another task while tracking)
    let triggerPlayFlash = false;
    if (isTracking && (!wasTracking || (activeTask && String(activeTask.id) !== previousTrackedTaskId))) {
      triggerPlayFlash = true;
    }

    // Detect focus completion / break
    let forceFinishedAlert = false;
    if (!previousIsBreak && isBreak) {
      forceFinishedAlert = true;
    }
    if (previousRemaining > 1 && remainingSeconds <= 0 && isTracking) {
      forceFinishedAlert = true;
    }

    // Detect Estimate Exceeded / Finished
    let triggerOvertimeFlash = false;
    const timeSpentMs = activeTask?.timeSpent || 0;
    const timeEstimateMs = activeTask?.timeEstimate || 0;

    if (isTracking && timeEstimateMs > 0 && timeSpentMs >= timeEstimateMs) {
      const overtimeKey = `${activeTask.id}_${timeEstimateMs}`;
      if (!alertedOvertimeMap.has(overtimeKey)) {
        alertedOvertimeMap.add(overtimeKey);
        triggerOvertimeFlash = true;
      }
    } else if (!isTracking) {
      alertedOvertimeMap.clear();
    }

    wasTracking = isTracking;
    previousTrackedTaskId = isTracking && activeTask ? String(activeTask.id) : null;
    previousIsBreak = isBreak;
    previousRemaining = remainingSeconds;

    // Prepare payload
    const title = isTracking && activeTask?.title ? String(activeTask.title) : "";
    const taskId = isTracking && activeTask?.id ? String(activeTask.id) : null;
    const taskNotes = String(activeTask?.notes || "");

    const payload = {
      isTracking,
      taskTitle: title,
      timeSpentMs,
      timeEstimateMs,
      remainingSeconds,
      focusDurationSeconds,
      isBreak,
      taskId,
      taskNotes,
      habits: mappedHabits,
      triggerPlayFlash,
      triggerOvertimeFlash,
      forceFinishedAlert
    };

    const payloadString = JSON.stringify(payload);
    if (payloadString !== lastPayloadString || triggerPlayFlash || triggerOvertimeFlash || forceFinishedAlert) {
      lastPayloadString = payloadString;
      await fetch(`${FOCO_DS_BRIDGE_URL}/state`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: payloadString,
      }).catch(() => {});
    }

    // Poll commands from Foco DS
    try {
      const cmdRes = await fetch(`${FOCO_DS_BRIDGE_URL}/commands`);
      if (cmdRes.ok) {
        const commands = await cmdRes.json();
        if (Array.isArray(commands)) {
          for (const cmd of commands) {
            if (cmd.type === "focus_task" && cmd.taskId) {
              state.activeTaskId = String(cmd.taskId);
              state.running = true;
              if (typeof PluginAPI.dispatchAction === "function") {
                PluginAPI.dispatchAction({ type: "[Task] SetCurrentTask", id: cmd.taskId });
                PluginAPI.dispatchAction({ type: "[Task] SelectTask", id: cmd.taskId });
              }
              if (typeof window !== "undefined") {
                window.location.hash = "#/tag/TODAY/tasks";
              }
            } else if (cmd.type === "update_notes" && cmd.taskId) {
              if (typeof PluginAPI.updateTask === "function") {
                await PluginAPI.updateTask(cmd.taskId, { notes: String(cmd.notes || "") });
              }
            } else if (cmd.type === "update_task_estimate" && cmd.taskId) {
              const newEst = Number(cmd.timeEstimateMs || 0);
              if (typeof PluginAPI.updateTask === "function") {
                await PluginAPI.updateTask(cmd.taskId, { timeEstimate: newEst });
              } else if (typeof PluginAPI.dispatchAction === "function") {
                PluginAPI.dispatchAction({
                  type: "[Task] UpdateTask",
                  task: { id: cmd.taskId, changes: { timeEstimate: newEst } }
                });
              }
            } else if (cmd.type === "increment_habit" && cmd.habitId) {
              if (typeof PluginAPI.incrementCounter === "function") {
                await PluginAPI.incrementCounter(cmd.habitId, 1);
              } else if (typeof PluginAPI.dispatchAction === "function") {
                PluginAPI.dispatchAction({
                  type: "[SimpleCounter] Increase counter today",
                  id: cmd.habitId,
                  increaseBy: 1
                });
              }
            } else if (cmd.type === "toggle_habit" && cmd.habitId) {
              if (typeof PluginAPI.toggleSimpleCounter === "function") {
                await PluginAPI.toggleSimpleCounter(cmd.habitId);
              } else if (typeof PluginAPI.dispatchAction === "function") {
                PluginAPI.dispatchAction({
                  type: "[SimpleCounter] Toggle SimpleCounter Counter",
                  id: cmd.habitId
                });
              }
            }
          }
        }
      }
    } catch (e) {}

  } catch (err) {
  } finally {
    isSyncing = false;
  }
}

// Register Hooks
function registerHooks() {
  if (typeof PluginAPI !== "undefined" && typeof PluginAPI.registerHook === "function") {
    // Current task change hook
    try {
      PluginAPI.registerHook("currentTaskChange", (payload) => {
        const current = payload && payload.current ? payload.current : payload;
        if (current && current.id) {
          state.activeTaskId = String(current.id);
          state.running = true;
        } else {
          state.running = false;
        }
        setTimeout(syncState, 20);
      });
    } catch (e) {}

    // Action hook
    try {
      PluginAPI.registerHook("action", (payload) => {
        const action = payload && payload.action ? payload.action : payload;
        if (!action || !action.type) return;

        if (action.type === "[Task] SetCurrentTask") {
          if (action.id) {
            state.activeTaskId = String(action.id);
            state.running = true;
          } else {
            state.running = false;
          }
          setTimeout(syncState, 20);
        } else if (action.type === "[Task] Toggle start") {
          state.running = !state.running;
          setTimeout(syncState, 20);
        } else if (action.type.includes("TimeTracking") || action.type.includes("Task")) {
          setTimeout(syncState, 40);
        }
      });
    } catch (e) {}

    // Other life-cycle hooks
    [
      "taskCreated",
      "taskUpdate",
      "taskComplete",
      "taskDelete",
      "anyTaskUpdate",
      "workContextChange"
    ].forEach((h) => {
      try {
        PluginAPI.registerHook(h, () => {
          setTimeout(syncState, 50);
        });
      } catch (e) {}
    });
  }
}

registerHooks();
setInterval(syncState, SYNC_INTERVAL_MS);
setTimeout(syncState, 50);
