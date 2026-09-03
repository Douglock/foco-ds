/**
 * Foco DS - High Precision Timer Engine
 * Uses timestamp drift-correction for flawless background & tab accuracy
 */

export class TimerEngine {
  constructor(options = {}) {
    this.totalSeconds = options.initialDurationMinutes ? options.initialDurationMinutes * 60 : 25 * 60;
    this.remainingSeconds = this.totalSeconds;
    this.mode = 'focus'; // 'focus', 'short_break', 'long_break'
    this.state = 'IDLE'; // 'IDLE', 'RUNNING', 'PAUSED'
    this.endTime = null;
    this.intervalId = null;

    this.onTick = options.onTick || (() => {});
    this.onComplete = options.onComplete || (() => {});
    this.onStateChange = options.onStateChange || (() => {});
  }

  setMode(mode, durationMinutes) {
    this.pause();
    this.mode = mode;
    this.totalSeconds = Math.max(1, durationMinutes) * 60;
    this.remainingSeconds = this.totalSeconds;
    this.state = 'IDLE';
    this.onStateChange(this.state, this.mode);
    this.triggerTick();
  }

  start() {
    if (this.state === 'RUNNING') return;

    this.state = 'RUNNING';
    this.endTime = Date.now() + (this.remainingSeconds * 1000);
    this.onStateChange(this.state, this.mode);

    this.intervalId = setInterval(() => {
      const now = Date.now();
      const diffMs = this.endTime - now;

      if (diffMs <= 0) {
        this.remainingSeconds = 0;
        this.triggerTick();
        this.complete();
      } else {
        this.remainingSeconds = Math.ceil(diffMs / 1000);
        this.triggerTick();
      }
    }, 250); // fast check for smooth countdown
  }

  pause() {
    if (this.state !== 'RUNNING') return;

    clearInterval(this.intervalId);
    this.intervalId = null;
    this.state = 'PAUSED';
    this.onStateChange(this.state, this.mode);
  }

  toggle() {
    if (this.state === 'RUNNING') {
      this.pause();
    } else {
      this.start();
    }
  }

  reset() {
    this.pause();
    this.remainingSeconds = this.totalSeconds;
    this.state = 'IDLE';
    this.onStateChange(this.state, this.mode);
    this.triggerTick();
  }

  complete() {
    clearInterval(this.intervalId);
    this.intervalId = null;
    this.state = 'COMPLETED';
    const durationMinutes = Math.round(this.totalSeconds / 60);
    this.onStateChange(this.state, this.mode);
    this.onComplete(this.mode, durationMinutes);
  }

  triggerTick() {
    const progress = Math.min(1, Math.max(0, 1 - (this.remainingSeconds / this.totalSeconds)));
    this.onTick({
      remainingSeconds: this.remainingSeconds,
      totalSeconds: this.totalSeconds,
      progress: progress,
      formattedTime: this.getFormattedTime()
    });
  }

  getFormattedTime() {
    const m = Math.floor(this.remainingSeconds / 60);
    const s = this.remainingSeconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
}
