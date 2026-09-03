/**
 * Foco DS - Application Controller
 * Connects TimerEngine, AudioEngine, StorageManager and Interactive UI
 */

import { TimerEngine } from './modules/timer.js';
import { audio } from './modules/audio.js';
import { StorageManager } from './modules/storage.js';

// DOM Elements
const timerOuter = document.querySelector('.timer-outer');
const timerProgressCircle = document.getElementById('timerProgressCircle');
const timerDigits = document.getElementById('timerDigits');
const sessionModeBadge = document.getElementById('sessionModeBadge');
const sessionStatus = document.getElementById('sessionStatus');

const btnToggle = document.getElementById('btnToggle');
const btnToggleIcon = document.getElementById('btnToggleIcon');
const btnToggleText = document.getElementById('btnToggleText');
const btnReset = document.getElementById('btnReset');
const btnSkip = document.getElementById('btnSkip');

const inputGoal = document.getElementById('inputGoal');
const headerStreak = document.getElementById('headerStreak');
const headerMinutes = document.getElementById('headerMinutes');
const soundIndicator = document.getElementById('soundIndicator');

// Modals & Backdrops
const btnOpenStats = document.getElementById('btnOpenStats');
const modalStatsBackdrop = document.getElementById('modalStatsBackdrop');
const btnCloseStats = document.getElementById('btnCloseStats');
const btnDoneStats = document.getElementById('btnDoneStats');

const btnOpenSound = document.getElementById('btnOpenSound');
const modalSoundBackdrop = document.getElementById('modalSoundBackdrop');
const btnCloseSound = document.getElementById('btnCloseSound');
const btnDoneSound = document.getElementById('btnDoneSound');
const soundChips = document.querySelectorAll('.sound-chip');
const volumeSlider = document.getElementById('volumeSlider');

const btnOpenNotes = document.getElementById('btnOpenNotes');
const modalNotesBackdrop = document.getElementById('modalNotesBackdrop');
const btnCloseNotes = document.getElementById('btnCloseNotes');
const btnDoneNotes = document.getElementById('btnDoneNotes');
const btnClearNotes = document.getElementById('btnClearNotes');
const scratchpadTextarea = document.getElementById('scratchpadTextarea');

const btnCustomModal = document.getElementById('btnCustomModal');
const modalCustomBackdrop = document.getElementById('modalCustomBackdrop');
const btnCloseCustom = document.getElementById('btnCloseCustom');
const btnCancelCustom = document.getElementById('btnCancelCustom');
const btnApplyCustom = document.getElementById('btnApplyCustom');
const customMinutesSlider = document.getElementById('customMinutesSlider');
const customMinutesLabel = document.getElementById('customMinutesLabel');

const btnFullscreen = document.getElementById('btnFullscreen');
const toastNotice = document.getElementById('toastNotice');
const toastMessage = document.getElementById('toastMessage');

const presetCards = document.querySelectorAll('.preset-card[data-mode]');

// SVG Circle circumference for r=140
const CIRCLE_CIRCUMFERENCE = 2 * Math.PI * 140; // ~879.64

// Initialize Timer Engine
const timer = new TimerEngine({
  initialDurationMinutes: 25,
  onTick: handleTick,
  onComplete: handleSessionComplete,
  onStateChange: handleStateChange
});

// App State
let currentSettings = StorageManager.loadSettings();
let stats = StorageManager.loadStats();

// Initialize Application
function init() {
  // Setup circle dasharray
  timerProgressCircle.style.strokeDasharray = `${CIRCLE_CIRCUMFERENCE}`;
  timerProgressCircle.style.strokeDashoffset = '0';

  // Load Saved Goal
  inputGoal.value = StorageManager.loadGoal();
  inputGoal.addEventListener('input', (e) => {
    StorageManager.saveGoal(e.target.value);
  });

  // Load Saved Notes
  scratchpadTextarea.value = StorageManager.loadNotes();
  scratchpadTextarea.addEventListener('input', (e) => {
    StorageManager.saveNotes(e.target.value);
  });

  // Load Sound Settings
  if (currentSettings.ambientType) {
    updateSoundChipSelection(currentSettings.ambientType);
  }
  if (currentSettings.volume !== undefined) {
    volumeSlider.value = currentSettings.volume;
    audio.setAmbientVolume(currentSettings.volume);
  }

  // Update Stats Header
  refreshStatsDisplay();

  // Setup Event Listeners
  setupEventListeners();

  // Initial Tick Update
  timer.triggerTick();
}

function handleTick({ progress, formattedTime }) {
  timerDigits.textContent = formattedTime;
  document.title = `${formattedTime} • Foco DS`;

  // Circular progress: from 0 (full) to CIRCLE_CIRCUMFERENCE (empty)
  const offset = CIRCLE_CIRCUMFERENCE * progress;
  timerProgressCircle.style.strokeDashoffset = `${offset}`;
}

function handleStateChange(state, mode) {
  const isBreak = mode.includes('break');

  // Mode badge & timer styling
  if (mode === 'focus') {
    sessionModeBadge.textContent = 'Sessão de Foco';
    timerOuter.classList.remove('break');
  } else if (mode === 'short_break') {
    sessionModeBadge.textContent = 'Pausa Curta';
    timerOuter.classList.add('break');
  } else if (mode === 'long_break') {
    sessionModeBadge.textContent = 'Pausa Longa';
    timerOuter.classList.add('break');
  }

  // Running vs Idle vs Paused
  if (state === 'RUNNING') {
    timerOuter.classList.add('running');
    btnToggle.classList.add('running');
    btnToggleIcon.textContent = '⏸';
    btnToggleText.textContent = 'Pausar';
    sessionStatus.textContent = isBreak ? 'Aproveite para relaxar' : 'Foco absoluto no momento';

    // Start ambient sound if selected
    if (currentSettings.ambientType && currentSettings.ambientType !== 'none') {
      audio.setAmbientSound(currentSettings.ambientType);
      soundIndicator.classList.add('active');
    }
  } else if (state === 'PAUSED') {
    timerOuter.classList.remove('running');
    btnToggle.classList.remove('running');
    btnToggleIcon.textContent = '▶';
    btnToggleText.textContent = 'Continuar';
    sessionStatus.textContent = 'Sessão em pausa';
  } else if (state === 'IDLE') {
    timerOuter.classList.remove('running');
    btnToggle.classList.remove('running');
    btnToggleIcon.textContent = '▶';
    btnToggleText.textContent = isBreak ? 'Iniciar Pausa' : 'Iniciar Foco';
    sessionStatus.textContent = 'Pronto para começar';
    timerProgressCircle.style.strokeDashoffset = '0';

    // Stop ambient sound
    audio.stopAmbientSound();
    soundIndicator.classList.remove('active');
  }
}

function handleSessionComplete(mode, durationMinutes) {
  audio.playCompletionChime();

  if (mode === 'focus') {
    stats = StorageManager.recordCompletedSession(durationMinutes);
    refreshStatsDisplay();
    showToast(`🎉 Sessão de ${durationMinutes} min concluída com sucesso!`);
    
    // Auto switch to short break
    setTimeout(() => {
      selectPresetMode('short_break', 5);
    }, 1500);
  } else {
    showToast('☕ Pausa encerrada! Pronto para o próximo ciclo de foco?');
    setTimeout(() => {
      selectPresetMode('focus', 25);
    }, 1500);
  }
}

function refreshStatsDisplay() {
  stats = StorageManager.loadStats();
  headerStreak.textContent = `${stats.streak} ${stats.streak === 1 ? 'dia' : 'dias'}`;
  headerMinutes.textContent = `${stats.minutesToday}m`;

  const modalStreak = document.getElementById('modalStatStreak');
  const modalMinutes = document.getElementById('modalStatMinutes');
  const modalSessions = document.getElementById('modalStatSessions');

  if (modalStreak) modalStreak.textContent = stats.streak;
  if (modalMinutes) modalMinutes.textContent = stats.minutesToday;
  if (modalSessions) modalSessions.textContent = stats.sessionsToday;

  renderWeeklyChart(stats);
}

function renderWeeklyChart(stats) {
  const container = document.getElementById('weeklyBarsContainer');
  if (!container) return;
  container.innerHTML = '';

  const dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  const today = new Date();
  const past7Days = [];

  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(today.getDate() - i);
    const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    const dayLabel = dayNames[d.getDay()];
    const mins = (stats.history && stats.history[dateStr]) || 0;
    past7Days.push({ label: dayLabel, minutes: mins, isToday: i === 0 });
  }

  const maxMinutes = Math.max(60, ...past7Days.map(d => d.minutes));

  past7Days.forEach(item => {
    const col = document.createElement('div');
    col.className = 'weekly-bar-col';

    const heightPct = Math.max(6, Math.round((item.minutes / maxMinutes) * 100));

    col.innerHTML = `
      <div class="bar-fill" style="height: ${heightPct}%; ${item.isToday ? 'background: #34d399;' : ''}" title="${item.minutes} minutos"></div>
      <span class="bar-label" style="${item.isToday ? 'color: #34d399; font-weight: bold;' : ''}">${item.label}</span>
    `;

    container.appendChild(col);
  });
}

function selectPresetMode(mode, duration) {
  presetCards.forEach(card => {
    if (card.dataset.mode === mode && parseInt(card.dataset.duration, 10) === duration) {
      card.classList.add('active');
    } else {
      card.classList.remove('active');
    }
  });

  timer.setMode(mode, duration);
}

function showToast(msg) {
  toastMessage.textContent = msg;
  toastNotice.classList.add('show');
  setTimeout(() => {
    toastNotice.classList.remove('show');
  }, 4000);
}

function updateSoundChipSelection(type) {
  soundChips.forEach(chip => {
    if (chip.dataset.sound === type) {
      chip.classList.add('active');
    } else {
      chip.classList.remove('active');
    }
  });
}

// Event Listeners Setup
function setupEventListeners() {
  // Controls
  btnToggle.addEventListener('click', () => {
    audio.playClick();
    timer.toggle();
  });

  btnReset.addEventListener('click', () => {
    audio.playClick();
    timer.reset();
  });

  btnSkip.addEventListener('click', () => {
    audio.playClick();
    if (confirm('Deseja pular para o próximo ciclo?')) {
      if (timer.mode === 'focus') {
        selectPresetMode('short_break', 5);
      } else {
        selectPresetMode('focus', 25);
      }
    }
  });

  // Presets
  presetCards.forEach(card => {
    card.addEventListener('click', () => {
      audio.playClick();
      const mode = card.dataset.mode;
      const duration = parseInt(card.dataset.duration, 10);
      selectPresetMode(mode, duration);
    });
  });

  // Custom Duration Modal
  btnCustomModal.addEventListener('click', () => {
    openModal(modalCustomBackdrop);
  });
  btnCloseCustom.addEventListener('click', () => closeModal(modalCustomBackdrop));
  btnCancelCustom.addEventListener('click', () => closeModal(modalCustomBackdrop));

  customMinutesSlider.addEventListener('input', (e) => {
    customMinutesLabel.textContent = e.target.value;
  });

  btnApplyCustom.addEventListener('click', () => {
    const mins = parseInt(customMinutesSlider.value, 10);
    presetCards.forEach(c => c.classList.remove('active'));
    btnCustomModal.classList.add('active');
    timer.setMode('focus', mins);
    closeModal(modalCustomBackdrop);
    showToast(`Tempo personalizado definido: ${mins} minutos.`);
  });

  // Stats Modal
  btnOpenStats.addEventListener('click', () => {
    refreshStatsDisplay();
    openModal(modalStatsBackdrop);
  });
  btnCloseStats.addEventListener('click', () => closeModal(modalStatsBackdrop));
  btnDoneStats.addEventListener('click', () => closeModal(modalStatsBackdrop));

  // Sound Modal
  btnOpenSound.addEventListener('click', () => openModal(modalSoundBackdrop));
  btnCloseSound.addEventListener('click', () => closeModal(modalSoundBackdrop));
  btnDoneSound.addEventListener('click', () => closeModal(modalSoundBackdrop));

  soundChips.forEach(chip => {
    chip.addEventListener('click', () => {
      const soundType = chip.dataset.sound;
      updateSoundChipSelection(soundType);
      currentSettings.ambientType = soundType;
      StorageManager.saveSettings(currentSettings);

      if (timer.state === 'RUNNING') {
        audio.setAmbientSound(soundType);
        if (soundType !== 'none') {
          soundIndicator.classList.add('active');
        } else {
          soundIndicator.classList.remove('active');
        }
      }
    });
  });

  volumeSlider.addEventListener('input', (e) => {
    const vol = parseFloat(e.target.value);
    currentSettings.volume = vol;
    audio.setAmbientVolume(vol);
    StorageManager.saveSettings(currentSettings);
  });

  // Notes Modal
  btnOpenNotes.addEventListener('click', () => openModal(modalNotesBackdrop));
  btnCloseNotes.addEventListener('click', () => closeModal(modalNotesBackdrop));
  btnDoneNotes.addEventListener('click', () => closeModal(modalNotesBackdrop));

  btnClearNotes.addEventListener('click', () => {
    if (confirm('Limpar todas as anotações do bloco?')) {
      scratchpadTextarea.value = '';
      StorageManager.saveNotes('');
    }
  });

  // Fullscreen
  btnFullscreen.addEventListener('click', () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  });

  // Keyboard Shortcuts
  window.addEventListener('keydown', (e) => {
    const isTyping = ['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName);
    if (isTyping) return;

    if (e.code === 'Space') {
      e.preventDefault();
      timer.toggle();
    } else if (e.key === 'r' || e.key === 'R') {
      timer.reset();
    } else if (e.key === 'n' || e.key === 'N') {
      toggleModal(modalNotesBackdrop);
    } else if (e.key === 'm' || e.key === 'M') {
      toggleModal(modalSoundBackdrop);
    }
  });

  // Close modals on backdrop click
  [modalStatsBackdrop, modalSoundBackdrop, modalNotesBackdrop, modalCustomBackdrop].forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        closeModal(modal);
      }
    });
  });
}

function openModal(el) {
  el.classList.add('open');
}

function closeModal(el) {
  el.classList.remove('open');
}

function toggleModal(el) {
  if (el.classList.contains('open')) {
    closeModal(el);
  } else {
    openModal(el);
  }
}

// Run on page load
document.addEventListener('DOMContentLoaded', init);
