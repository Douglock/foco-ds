let totalSeconds = 25 * 60;
let remainingSeconds = totalSeconds;
let intervalId = null;
let isRunning = false;

const timerDisplay = document.getElementById('timerDisplay');
const btnToggle = document.getElementById('btnToggle');
const btnReset = document.getElementById('btnReset');
const modeChips = document.querySelectorAll('.mode-chip');

function updateDisplay() {
  const minutes = Math.floor(remainingSeconds / 60);
  const seconds = remainingSeconds % 60;
  timerDisplay.textContent = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  document.title = `${timerDisplay.textContent} • Foco DS`;
}

function startTimer() {
  if (isRunning) return;
  isRunning = true;
  btnToggle.textContent = 'Pausar Foco';
  btnToggle.classList.add('running');

  intervalId = setInterval(() => {
    if (remainingSeconds > 0) {
      remainingSeconds--;
      updateDisplay();
    } else {
      pauseTimer();
      alert('Sessão de foco concluída com sucesso!');
    }
  }, 1000);
}

function pauseTimer() {
  isRunning = false;
  clearInterval(intervalId);
  btnToggle.textContent = 'Iniciar Foco';
  btnToggle.classList.remove('running');
}

function resetTimer() {
  pauseTimer();
  remainingSeconds = totalSeconds;
  updateDisplay();
}

btnToggle.addEventListener('click', () => {
  if (isRunning) {
    pauseTimer();
  } else {
    startTimer();
  }
});

btnReset.addEventListener('click', resetTimer);

modeChips.forEach(chip => {
  chip.addEventListener('click', () => {
    modeChips.forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    const minutes = parseInt(chip.dataset.time, 10);
    totalSeconds = minutes * 60;
    resetTimer();
  });
});

updateDisplay();
