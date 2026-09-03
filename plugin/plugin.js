/**
 * Foco DS — Super Productivity Integration Plugin
 * Minimalist, ultra-lightweight status broadcaster & bidirectional notes sync.
 */

const FOCO_DS_BRIDGE_URL = "http://127.0.0.1:28475";
const SYNC_INTERVAL_MS = 1000;

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

    // 1. Fetch data from PluginAPI if available
    if (typeof PluginAPI !== "undefined") {
      // Current context tasks
      if (typeof PluginAPI.getCurrentContextTasks === "function") {
        const tasks = await PluginAPI.getCurrentContextTasks();
        if (Array.isArray(tasks)) {
          activeTask = tasks.find(t => t && (t.isCurrent || (t.timeSpentOnDay > 0 && t.timeSpent > 0))) || tasks[0];
        }
      }

      // Check global app state
      if (typeof PluginAPI.getAppState === "function") {
        const appState = await PluginAPI.getAppState();
        if (appState?.tasks?.currentTaskId) {
          const currentId = String(appState.tasks.currentTaskId);
          if (typeof PluginAPI.getTasks === "function") {
            const allTasks = await PluginAPI.getTasks();
            if (Array.isArray(allTasks)) {
              const matched = allTasks.find(t => String(t.id) === currentId);
              if (matched) activeTask = matched;
            }
          }
        }
        isTracking = Boolean(appState?.timeTracking?.isTracking || appState?.tasks?.currentTaskId);
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

    // 3. Prepare payload with notes
    const title = activeTask?.title || (isTracking ? "Em Foco" : "Foco DS");
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
            if (cmd.type === "update_notes" && cmd.taskId) {
              if (typeof PluginAPI.updateTask === "function") {
                await PluginAPI.updateTask(cmd.taskId, { notes: String(cmd.notes || "") });
              }
            }
          }
        }
      }
    } catch (e) {}

  } catch (err) {
    // Maintain low overhead
  }
}

// Start continuous loop
setInterval(syncState, SYNC_INTERVAL_MS);
syncState();
