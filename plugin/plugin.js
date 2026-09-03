/**
 * Foco DS — Super Productivity Integration Plugin
 * Minimalist, ultra-lightweight status broadcaster.
 * Read-only: sends active task and timer to Foco DS HUD.
 */

const FOCO_DS_BRIDGE_URL = "http://127.0.0.1:28475/state";
const SYNC_INTERVAL_MS = 1000;

let lastPayloadString = "";

async function syncState() {
  try {
    let activeTask = null;
    let isTracking = false;
    let isBreak = false;

    // 1. Check if PluginAPI is available
    if (typeof PluginAPI !== "undefined") {
      // Check active context tasks
      if (typeof PluginAPI.getCurrentContextTasks === "function") {
        const tasks = await PluginAPI.getCurrentContextTasks();
        if (Array.isArray(tasks)) {
          // Look for task with subtasks or currently active
          activeTask = tasks.find(t => t && (t.isCurrent || t.timeSpentOnDay > 0 && t.timeSpent > 0)) || tasks[0];
        }
      }

      // Check global app state if available
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
      }
    }

    // 2. Prepare payload
    const title = activeTask?.title || (isTracking ? "Em Foco" : "Foco DS");
    const timeSpentMs = activeTask?.timeSpent || 0;
    const timeEstimateMs = activeTask?.timeEstimate || 0;
    const taskId = activeTask?.id ? String(activeTask.id) : null;

    const payload = {
      isTracking,
      taskTitle: title,
      timeSpentMs,
      timeEstimateMs,
      isBreak,
      taskId
    };

    const payloadString = JSON.stringify(payload);
    // Only send when data changes or periodically
    if (payloadString !== lastPayloadString) {
      lastPayloadString = payloadString;
      await fetch(FOCO_DS_BRIDGE_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: payloadString,
      }).catch(() => {});
    }
  } catch (err) {
    // Silently continue to maintain low overhead
  }
}

// Start continuous polling loop
setInterval(syncState, SYNC_INTERVAL_MS);
syncState();
