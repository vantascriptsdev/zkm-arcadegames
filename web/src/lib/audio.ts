import { surface } from "./nui";

const MASTER_VOLUME = 0.32;
const NEAR_SILENCE = 0.0001;
const ATTACK_SECONDS = 0.012;
const RELEASE_TAIL_SECONDS = 0.02;

const soundEnabled = surface === "nui";

let sharedAudioContext: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  if (!soundEnabled || typeof AudioContext === "undefined") return null;
  sharedAudioContext ??= new AudioContext();
  if (sharedAudioContext.state === "suspended") void sharedAudioContext.resume();
  return sharedAudioContext;
}

interface Tone {
  startTime: number;
  duration: number;
  startFrequency: number;
  endFrequency?: number;
  waveform?: OscillatorType;
  peak?: number;
}

function scheduleTone(audioContext: AudioContext, tone: Tone) {
  const endTime = tone.startTime + tone.duration;
  const oscillator = audioContext.createOscillator();
  const envelope = audioContext.createGain();

  oscillator.type = tone.waveform ?? "sine";
  oscillator.frequency.setValueAtTime(tone.startFrequency, tone.startTime);
  if (tone.endFrequency !== undefined) {
    oscillator.frequency.exponentialRampToValueAtTime(tone.endFrequency, endTime);
  }

  envelope.gain.setValueAtTime(NEAR_SILENCE, tone.startTime);
  envelope.gain.exponentialRampToValueAtTime(
    (tone.peak ?? 1) * MASTER_VOLUME,
    tone.startTime + ATTACK_SECONDS
  );
  envelope.gain.exponentialRampToValueAtTime(NEAR_SILENCE, endTime);

  oscillator.connect(envelope).connect(audioContext.destination);
  oscillator.start(tone.startTime);
  oscillator.stop(endTime + RELEASE_TAIL_SECONDS);
}

function scheduleNoiseBurst(
  audioContext: AudioContext,
  startTime: number,
  duration: number,
  peak: number
) {
  const frameCount = Math.ceil(audioContext.sampleRate * duration);
  const noiseBuffer = audioContext.createBuffer(1, frameCount, audioContext.sampleRate);
  const samples = noiseBuffer.getChannelData(0);

  for (let frameIndex = 0; frameIndex < frameCount; frameIndex += 1) {
    const decay = (1 - frameIndex / frameCount) ** 2;
    samples[frameIndex] = (Math.random() * 2 - 1) * decay;
  }

  const bufferSource = audioContext.createBufferSource();
  const lowpassFilter = audioContext.createBiquadFilter();
  const outputGain = audioContext.createGain();

  bufferSource.buffer = noiseBuffer;
  lowpassFilter.type = "lowpass";
  lowpassFilter.frequency.setValueAtTime(1400, startTime);
  lowpassFilter.frequency.exponentialRampToValueAtTime(220, startTime + duration);
  outputGain.gain.setValueAtTime(peak * MASTER_VOLUME, startTime);

  bufferSource.connect(lowpassFilter).connect(outputGain).connect(audioContext.destination);
  bufferSource.start(startTime);
  bufferSource.stop(startTime + duration);
}

const PENTATONIC_SEMITONES = [0, 2, 4, 7, 9];
const SEMITONE_RATIO = 2 ** (1 / 12);

function stepFrequency(baseFrequency: number, step: number, maxOctaves: number): number {
  const degree = step % PENTATONIC_SEMITONES.length;
  const octave = Math.min(Math.floor(step / PENTATONIC_SEMITONES.length), maxOctaves);
  return baseFrequency * SEMITONE_RATIO ** PENTATONIC_SEMITONES[degree] * 2 ** octave;
}

const WIN_ARPEGGIO = [1046.5, 1318.5, 1568.0, 2093.0];
const WIN_NOTE_SPACING_SECONDS = 0.062;

const PEG_HIT_LOWEST_FREQUENCY = 680;
const PEG_HIT_HIGHEST_FREQUENCY = 1240;
const PEG_HIT_DETUNE_RATIO = 0.045;
const PEG_HIT_DROP_RATIO = 0.55;

const BET_TICK_MIN_GAP_SECONDS = 0.04;

let lastBetTickTime = 0;

export function playRoundStart() {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;

  scheduleTone(audioContext, {
    startTime,
    duration: 0.07,
    startFrequency: 520,
    endFrequency: 760,
    waveform: "square",
    peak: 0.2
  });
  scheduleTone(audioContext, {
    startTime: startTime + 0.075,
    duration: 0.11,
    startFrequency: 780,
    endFrequency: 1180,
    waveform: "square",
    peak: 0.18
  });
}

export function playWin() {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;

  WIN_ARPEGGIO.forEach((frequency, noteIndex) => {
    scheduleTone(audioContext, {
      startTime: startTime + noteIndex * WIN_NOTE_SPACING_SECONDS,
      duration: 0.16,
      startFrequency: frequency,
      waveform: "triangle",
      peak: 0.5
    });
  });

  scheduleTone(audioContext, {
    startTime,
    duration: 0.42,
    startFrequency: 523.25,
    waveform: "sine",
    peak: 0.22
  });
}

export function playLoss() {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;

  scheduleTone(audioContext, {
    startTime,
    duration: 0.5,
    startFrequency: 300,
    endFrequency: 55,
    waveform: "sawtooth",
    peak: 0.34
  });
  scheduleTone(audioContext, {
    startTime,
    duration: 0.34,
    startFrequency: 140,
    endFrequency: 42,
    waveform: "sine",
    peak: 0.5
  });
  scheduleNoiseBurst(audioContext, startTime, 0.36, 0.5);
}

export function playCardDeal() {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;

  scheduleNoiseBurst(audioContext, startTime, 0.09, 0.34);
  scheduleTone(audioContext, {
    startTime,
    duration: 0.07,
    startFrequency: 420,
    endFrequency: 240,
    waveform: "triangle",
    peak: 0.22
  });
}

export function playBetTick() {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;
  if (startTime - lastBetTickTime < BET_TICK_MIN_GAP_SECONDS) return;
  lastBetTickTime = startTime;

  scheduleTone(audioContext, {
    startTime,
    duration: 0.03,
    startFrequency: 2100,
    endFrequency: 1500,
    waveform: "square",
    peak: 0.12
  });
}

export function playPegHit(descentProgress: number) {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;
  const descent = Math.min(1, Math.max(0, descentProgress));
  const detune = 1 + (Math.random() * 2 - 1) * PEG_HIT_DETUNE_RATIO;
  const frequency =
    (PEG_HIT_LOWEST_FREQUENCY +
      (PEG_HIT_HIGHEST_FREQUENCY - PEG_HIT_LOWEST_FREQUENCY) * descent) *
    detune;

  scheduleTone(audioContext, {
    startTime,
    duration: 0.055,
    startFrequency: frequency,
    endFrequency: frequency * PEG_HIT_DROP_RATIO,
    waveform: "triangle",
    peak: 0.34
  });
  scheduleNoiseBurst(audioContext, startTime, 0.018, 0.16);
}

const MILESTONE_BASE_FREQUENCY = 523.25;
const MILESTONE_MAX_OCTAVES = 2;
const MILESTONE_NOTE_SPACING_SECONDS = 0.052;
const MILESTONE_PEAK_TIER = 8;
const MILESTONE_FIFTH_RATIO = 1.5;
const MILESTONE_FIFTH_TIER = 2;
const MILESTONE_SHIMMER_TIER = 4;
const MILESTONE_SUB_TIER = 6;

export function playCrashMilestone(tier: number) {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;
  const step = Math.max(0, Math.floor(tier));
  const intensity = Math.min(1, step / MILESTONE_PEAK_TIER);
  const root = stepFrequency(MILESTONE_BASE_FREQUENCY, step, MILESTONE_MAX_OCTAVES);

  scheduleTone(audioContext, {
    startTime,
    duration: 0.1 + 0.06 * intensity,
    startFrequency: root,
    waveform: step >= MILESTONE_SHIMMER_TIER ? "square" : "triangle",
    peak: 0.3 + 0.22 * intensity
  });

  if (step >= MILESTONE_FIFTH_TIER) {
    scheduleTone(audioContext, {
      startTime: startTime + MILESTONE_NOTE_SPACING_SECONDS,
      duration: 0.13,
      startFrequency: root * MILESTONE_FIFTH_RATIO,
      waveform: "triangle",
      peak: 0.26 + 0.18 * intensity
    });
  }

  if (step >= MILESTONE_SHIMMER_TIER) {
    scheduleTone(audioContext, {
      startTime: startTime + MILESTONE_NOTE_SPACING_SECONDS * 2,
      duration: 0.18,
      startFrequency: root * 2,
      waveform: "sine",
      peak: 0.24 + 0.2 * intensity
    });
  }

  if (step >= MILESTONE_SUB_TIER) {
    scheduleTone(audioContext, {
      startTime,
      duration: 0.24,
      startFrequency: 150,
      endFrequency: 70,
      waveform: "sine",
      peak: 0.4 * intensity
    });
  }
}

const GEM_BASE_FREQUENCY = 587.33;
const GEM_MAX_OCTAVES = 2;
const GEM_NOTE_SPACING_SECONDS = 0.042;
const GEM_PEAK_STREAK = 10;
const GEM_FIFTH_RATIO = 1.5;
const GEM_FIFTH_STREAK = 3;
const GEM_SHIMMER_STREAK = 7;

export function playGemReveal(streak: number) {
  const audioContext = getAudioContext();
  if (!audioContext) return;

  const startTime = audioContext.currentTime;
  const step = Math.max(0, Math.floor(streak) - 1);
  const intensity = Math.min(1, step / GEM_PEAK_STREAK);
  const root = stepFrequency(GEM_BASE_FREQUENCY, step, GEM_MAX_OCTAVES);

  scheduleNoiseBurst(audioContext, startTime, 0.022, 0.14 + 0.1 * intensity);
  scheduleTone(audioContext, {
    startTime,
    duration: 0.11 + 0.05 * intensity,
    startFrequency: root,
    waveform: "sine",
    peak: 0.32 + 0.2 * intensity
  });

  if (step >= GEM_FIFTH_STREAK) {
    scheduleTone(audioContext, {
      startTime: startTime + GEM_NOTE_SPACING_SECONDS,
      duration: 0.12,
      startFrequency: root * GEM_FIFTH_RATIO,
      waveform: "triangle",
      peak: 0.2 + 0.18 * intensity
    });
  }

  if (step >= GEM_SHIMMER_STREAK) {
    scheduleTone(audioContext, {
      startTime: startTime + GEM_NOTE_SPACING_SECONDS * 2,
      duration: 0.2,
      startFrequency: root * 2,
      waveform: "sine",
      peak: 0.18 + 0.2 * intensity
    });
  }
}