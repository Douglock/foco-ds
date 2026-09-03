/**
 * Foco DS - Audio Engine
 * Pure Web Audio API Synthesizer (No external audio files needed)
 */

class AudioEngine {
  constructor() {
    this.ctx = null;
    this.ambientSource = null;
    this.ambientGain = null;
    this.currentAmbientType = 'none';
    this.ambientVolume = 0.4;
    this.binauralOscLeft = null;
    this.binauralOscRight = null;
  }

  initContext() {
    if (!this.ctx) {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AudioContextClass();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  // Play a gentle, soothing chime for completion
  playCompletionChime() {
    try {
      this.initContext();
      const now = this.ctx.currentTime;
      const frequencies = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6 (Major triad)

      frequencies.forEach((freq, index) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + index * 0.12);

        gain.gain.setValueAtTime(0, now + index * 0.12);
        gain.gain.linearRampToValueAtTime(0.25, now + index * 0.12 + 0.05);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + index * 0.12 + 1.8);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(now + index * 0.12);
        osc.stop(now + index * 0.12 + 2.0);
      });
    } catch (e) {
      console.warn('Audio playback error:', e);
    }
  }

  // Subtle click for buttons
  playClick() {
    try {
      this.initContext();
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(600, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(150, this.ctx.currentTime + 0.04);

      gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.04);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start();
      osc.stop(this.ctx.currentTime + 0.05);
    } catch (e) {}
  }

  // Ambient Noise Generators
  setAmbientSound(type) {
    this.stopAmbientSound();
    if (type === 'none') {
      this.currentAmbientType = 'none';
      return;
    }

    this.initContext();
    this.currentAmbientType = type;

    this.ambientGain = this.ctx.createGain();
    this.ambientGain.gain.setValueAtTime(this.ambientVolume, this.ctx.currentTime);
    this.ambientGain.connect(this.ctx.destination);

    if (type === 'brown') {
      this.playBrownNoise();
    } else if (type === 'rain') {
      this.playRainNoise();
    } else if (type === 'binaural') {
      this.playBinauralAlpha();
    }
  }

  setAmbientVolume(volume) {
    this.ambientVolume = Math.max(0, Math.min(1, volume));
    if (this.ambientGain && this.ctx) {
      this.ambientGain.gain.setTargetAtTime(this.ambientVolume, this.ctx.currentTime, 0.05);
    }
  }

  stopAmbientSound() {
    if (this.ambientSource) {
      try {
        this.ambientSource.stop();
        this.ambientSource.disconnect();
      } catch (e) {}
      this.ambientSource = null;
    }

    if (this.binauralOscLeft && this.binauralOscRight) {
      try {
        this.binauralOscLeft.stop();
        this.binauralOscRight.stop();
        this.binauralOscLeft.disconnect();
        this.binauralOscRight.disconnect();
      } catch (e) {}
      this.binauralOscLeft = null;
      this.binauralOscRight = null;
    }

    this.currentAmbientType = 'none';
  }

  playBrownNoise() {
    const bufferSize = 2 * this.ctx.sampleRate;
    const noiseBuffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    let lastOut = 0.0;

    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      output[i] = (lastOut + (0.02 * white)) / 1.02;
      lastOut = output[i];
      output[i] *= 3.5; // Gain compensation
    }

    this.ambientSource = this.ctx.createBufferSource();
    this.ambientSource.buffer = noiseBuffer;
    this.ambientSource.loop = true;

    // Filter to make it warm
    const lowpass = this.ctx.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.setValueAtTime(450, this.ctx.currentTime);

    this.ambientSource.connect(lowpass);
    lowpass.connect(this.ambientGain);
    this.ambientSource.start();
  }

  playRainNoise() {
    const bufferSize = 2 * this.ctx.sampleRate;
    const noiseBuffer = this.ctx.createBuffer(2, bufferSize, this.ctx.sampleRate);
    const left = noiseBuffer.getChannelData(0);
    const right = noiseBuffer.getChannelData(1);

    let b0_l = 0, b1_l = 0, b2_l = 0, b3_l = 0, b4_l = 0, b5_l = 0, b6_l = 0;
    let b0_r = 0, b1_r = 0, b2_r = 0, b3_r = 0, b4_r = 0, b5_r = 0, b6_r = 0;

    for (let i = 0; i < bufferSize; i++) {
      const white_l = Math.random() * 2 - 1;
      b0_l = 0.99886 * b0_l + white_l * 0.0555179;
      b1_l = 0.99332 * b1_l + white_l * 0.0750759;
      b2_l = 0.96900 * b2_l + white_l * 0.1538520;
      b3_l = 0.86650 * b3_l + white_l * 0.3104856;
      b4_l = 0.55000 * b4_l + white_l * 0.5329522;
      b5_l = -0.7616 * b5_l - white_l * 0.0168980;
      left[i] = (b0_l + b1_l + b2_l + b3_l + b4_l + b5_l + b6_l + white_l * 0.5362) * 0.08;
      b6_l = white_l * 0.115926;

      const white_r = Math.random() * 2 - 1;
      b0_r = 0.99886 * b0_r + white_r * 0.0555179;
      b1_r = 0.99332 * b1_r + white_r * 0.0750759;
      b2_r = 0.96900 * b2_r + white_r * 0.1538520;
      b3_r = 0.86650 * b3_r + white_r * 0.3104856;
      b4_r = 0.55000 * b4_r + white_r * 0.5329522;
      b5_r = -0.7616 * b5_r - white_r * 0.0168980;
      right[i] = (b0_r + b1_r + b2_r + b3_r + b4_r + b5_r + b6_r + white_r * 0.5362) * 0.08;
      b6_r = white_r * 0.115926;
    }

    this.ambientSource = this.ctx.createBufferSource();
    this.ambientSource.buffer = noiseBuffer;
    this.ambientSource.loop = true;

    const bandpass = this.ctx.createBiquadFilter();
    bandpass.type = 'bandpass';
    bandpass.frequency.setValueAtTime(800, this.ctx.currentTime);
    bandpass.Q.setValueAtTime(0.7, this.ctx.currentTime);

    this.ambientSource.connect(bandpass);
    bandpass.connect(this.ambientGain);
    this.ambientSource.start();
  }

  playBinauralAlpha() {
    // 200 Hz left ear, 210 Hz right ear = 10 Hz Alpha waves (Focus & Calm)
    const merger = this.ctx.createChannelMerger(2);

    this.binauralOscLeft = this.ctx.createOscillator();
    this.binauralOscLeft.type = 'sine';
    this.binauralOscLeft.frequency.setValueAtTime(196, this.ctx.currentTime);

    this.binauralOscRight = this.ctx.createOscillator();
    this.binauralOscRight.type = 'sine';
    this.binauralOscRight.frequency.setValueAtTime(206, this.ctx.currentTime); // 10Hz difference

    const leftGain = this.ctx.createGain();
    const rightGain = this.ctx.createGain();
    leftGain.gain.setValueAtTime(0.4, this.ctx.currentTime);
    rightGain.gain.setValueAtTime(0.4, this.ctx.currentTime);

    this.binauralOscLeft.connect(leftGain);
    this.binauralOscRight.connect(rightGain);

    leftGain.connect(merger, 0, 0);
    rightGain.connect(merger, 0, 1);

    merger.connect(this.ambientGain);

    this.binauralOscLeft.start();
    this.binauralOscRight.start();
  }
}

export const audio = new AudioEngine();
