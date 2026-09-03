/**
 * Foco DS - Storage & Analytics Module
 * Handles local persistence, streaks, session logging and quick notes
 */

const STORAGE_KEY_STATS = 'foco_ds_stats_v1';
const STORAGE_KEY_NOTES = 'foco_ds_scratchpad_v1';
const STORAGE_KEY_GOAL = 'foco_ds_current_goal_v1';
const STORAGE_KEY_SETTINGS = 'foco_ds_settings_v1';

function getTodayString() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export class StorageManager {
  static loadStats() {
    const today = getTodayString();
    const raw = localStorage.getItem(STORAGE_KEY_STATS);
    let stats = {
      today: today,
      minutesToday: 0,
      sessionsToday: 0,
      streak: 1,
      lastActiveDate: today,
      history: {} // { 'YYYY-MM-DD': minutes }
    };

    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        // Check if date changed
        if (parsed.today !== today) {
          const yesterday = new Date();
          yesterday.setDate(yesterday.getDate() - 1);
          const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
          
          let streak = parsed.streak || 1;
          if (parsed.lastActiveDate === yesterdayStr) {
            // Keep streak active
          } else if (parsed.lastActiveDate !== today) {
            streak = 1; // reset streak if missed a day
          }

          stats = {
            today: today,
            minutesToday: 0,
            sessionsToday: 0,
            streak: streak,
            lastActiveDate: parsed.lastActiveDate || today,
            history: parsed.history || {}
          };
        } else {
          stats = { ...stats, ...parsed };
        }
      } catch (e) {
        console.error('Failed to parse stats:', e);
      }
    }

    return stats;
  }

  static saveStats(stats) {
    try {
      localStorage.setItem(STORAGE_KEY_STATS, JSON.stringify(stats));
    } catch (e) {
      console.error('Failed to save stats:', e);
    }
  }

  static recordCompletedSession(minutes) {
    const stats = this.loadStats();
    const today = getTodayString();

    stats.minutesToday += minutes;
    stats.sessionsToday += 1;
    stats.lastActiveDate = today;
    stats.history = stats.history || {};
    stats.history[today] = (stats.history[today] || 0) + minutes;

    this.saveStats(stats);
    return stats;
  }

  static loadNotes() {
    return localStorage.getItem(STORAGE_KEY_NOTES) || '';
  }

  static saveNotes(notes) {
    localStorage.setItem(STORAGE_KEY_NOTES, notes);
  }

  static loadGoal() {
    return localStorage.getItem(STORAGE_KEY_GOAL) || '';
  }

  static saveGoal(goal) {
    localStorage.setItem(STORAGE_KEY_GOAL, goal);
  }

  static loadSettings() {
    const raw = localStorage.getItem(STORAGE_KEY_SETTINGS);
    const defaults = {
      ambientType: 'none',
      volume: 0.4,
      soundEnabled: true,
      notifications: false
    };
    if (raw) {
      try {
        return { ...defaults, ...JSON.parse(raw) };
      } catch (e) {}
    }
    return defaults;
  }

  static saveSettings(settings) {
    localStorage.setItem(STORAGE_KEY_SETTINGS, JSON.stringify(settings));
  }
}
