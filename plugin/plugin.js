/**
 * Foco DS — Super Productivity Integration Plugin
 * Minimalist, ultra-lightweight status broadcaster & bidirectional habits/task sync.
 */

const FOCO_DS_BRIDGE_URL = "http://127.0.0.1:28475";
const SYNC_INTERVAL_MS = 1000;

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

let lastPayloadString = "";
let wasTracking = false;
let previousIsBreak = false;
let previousRemaining = 0;

async function syncState() {
  try {
    let activeTask = null;
    let isTracking = false;
    let isBreak = false;
    let remainingSeconds = 0;
    let focusDurationSeconds = 25 * 60;
    let mappedHabits = [];

    // 1. Fetch data from PluginAPI if available
    if (typeof PluginAPI !== "undefined") {
      let appState = null;
      if (typeof PluginAPI.getAppState === "function") {
        try {
          appState = await PluginAPI.getAppState();
        } catch (e) {}
      }

      // Check active currentTaskId
      const currentTaskId = appState?.tasks?.currentTaskId ? String(appState.tasks.currentTaskId) : null;
      if (currentTaskId) {
        // Look up task in entities or via getTasks
        if (appState?.tasks?.entities && appState.tasks.entities[currentTaskId]) {
          activeTask = appState.tasks.entities[currentTaskId];
          isTracking = true;
        } else if (typeof PluginAPI.getTasks === "function") {
          try {
            const allTasks = await PluginAPI.getTasks();
            if (Array.isArray(allTasks)) {
              activeTask = allTasks.find(t => String(t.id) === currentTaskId);
              if (activeTask) isTracking = true;
            }
          } catch (e) {}
        }
      }

      // Check break status
      isBreak = Boolean(appState?.pomodoro?.isBreak);

      // Pomodoro timing
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

    // 2. Detect focus completion
    let forceFinishedAlert = false;
    if (!previousIsBreak && isBreak) {
      forceFinishedAlert = true;
    }
    if (previousRemaining > 1 && remainingSeconds <= 0 && isTracking) {
      forceFinishedAlert = true;
    }

    wasTracking = isTracking;
    previousIsBreak = isBreak;
    previousRemaining = remainingSeconds;

    // 3. Prepare payload
    const title = activeTask?.title ? String(activeTask.title) : "";
    const timeSpentMs = activeTask?.timeSpent || 0;
    const timeEstimateMs = activeTask?.timeEstimate || 0;
    const taskId = activeTask?.id ? String(activeTask.id) : null;
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
      forceFinishedAlert
    };

    const payloadString = JSON.stringify(payload);
    // Send state update
    if (payloadString !== lastPayloadString || forceFinishedAlert) {
      lastPayloadString = payloadString;
      await fetch(`${FOCO_DS_BRIDGE_URL}/state`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: payloadString,
      }).catch(() => {});
    }

    // 4. Poll and execute bidirectional commands from Foco DS
    try {
      const cmdRes = await fetch(`${FOCO_DS_BRIDGE_URL}/commands`);
      if (cmdRes.ok) {
        const commands = await cmdRes.json();
        if (Array.isArray(commands)) {
          for (const cmd of commands) {
            if (cmd.type === "focus_task" && cmd.taskId) {
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
            } else if (cmd.type === "open_habits") {
              if (typeof window !== "undefined") {
                window.location.hash = "#/habits";
              }
            }
          }
        }
      }
    } catch (e) {}

  } catch (err) {
    // Silent failover
  }
}

// Start continuous loop
setInterval(syncState, SYNC_INTERVAL_MS);
syncState();
