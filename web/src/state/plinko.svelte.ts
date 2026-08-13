import type { GameEngine, HistoryEntry, Phase, PlinkoOutcome, RiskLevel } from "../lib/types";
import type { Session } from "./session.svelte";
import { playLoss, playPegHit, playRoundStart, playWin } from "../lib/audio";

export const ROWS = 12;

export const SLOT_COUNT = ROWS + 1;

export const RISK_LEVELS: RiskLevel[] = ["LOW", "MED", "HIGH"];

const FIRST_STEP_MS = 130;
const LAST_STEP_MS = 370;
const STEP_SLOWDOWN_EXPONENT = 2;
const BREAK_EVEN_MULTIPLIER = 1;
const HISTORY_LIMIT = 6;
const COIN_FLIP = 0.5;

export class PlinkoEngine implements GameEngine {
  private readonly session: Session;

  phase = $state<Phase>("idle");
  risk = $state<RiskLevel>("MED");
  path = $state<number[]>([]);
  step = $state(-1);
  stepDurationMs = $state(0);
  slot = $state<number | null>(null);
  history = $state<HistoryEntry[]>([]);

  private timer: ReturnType<typeof setTimeout> | null = null;
  private landedSlot = 0;
  private landedMultiplier = 0;

  constructor(session: Session) {
    this.session = session;
  }

  get busy() {
    return this.phase === "live";
  }
  get payouts() {
    return this.session.config.plinkoPayouts[this.risk];
  }

  setRisk(risk: RiskLevel) {
    if (this.phase === "live") return;
    this.risk = risk;
  }

  async primary() {
    if (this.phase === "resolved") return this.reset();
    if (this.phase === "live") return;
    await this.drop();
  }

  async drop() {
    const outcome = await this.session.placeBet<PlinkoOutcome>(() => this.previewOutcome(), {
      risk: this.risk
    });

    if (!outcome) return;

    this.dropWithOutcome(outcome);
  }

  dropWithOutcome(outcome: PlinkoOutcome) {
    this.cleanup();
    this.path = outcome.path;
    this.landedSlot = outcome.slot;
    this.landedMultiplier = outcome.multiplier;
    this.phase = "live";
    this.step = 0;
    this.slot = null;
    this.stepDurationMs = this.stepDelayMs(0);
    playRoundStart();

    this.timer = setTimeout(() => this.tick(), this.stepDurationMs);
  }

  private previewOutcome(): PlinkoOutcome {
    const path = Array.from({ length: ROWS }, () => (Math.random() < COIN_FLIP ? -1 : 1));
    const drift = path.reduce((total, direction) => total + direction, 0);
    const slot = (drift + ROWS) / 2;

    return { path, slot, multiplier: this.payouts[slot] };
  }

  private stepDelayMs(step: number): number {
    const rowsTravelled = Math.max(1, ROWS - 1);
    const descent = Math.min(1, Math.max(0, step / rowsTravelled));
    const slowdown = descent ** STEP_SLOWDOWN_EXPONENT;
    const delay = FIRST_STEP_MS + (LAST_STEP_MS - FIRST_STEP_MS) * slowdown;
    return Math.round(delay);
  }

  private tick() {
    if (this.step >= ROWS) return this.land();

    const delay = this.stepDelayMs(this.step);
    this.stepDurationMs = delay;
    this.step += 1;
    playPegHit(this.step / ROWS);

    this.timer = setTimeout(() => this.tick(), delay);
  }

  private land() {
    this.cleanup();
    const multiplier = this.landedMultiplier;
    this.phase = "resolved";
    this.slot = this.landedSlot;
    this.history = [{ label: multiplier + "x" }, ...this.history].slice(0, HISTORY_LIMIT);

    if (multiplier >= BREAK_EVEN_MULTIPLIER) {
      playWin();
    } else {
      playLoss();
    }

    void this.session.settle(multiplier);
  }

  reset() {
    this.cleanup();
    this.phase = "idle";
    this.step = -1;
    this.stepDurationMs = 0;
    this.slot = null;
    this.path = [];
  }

  cleanup() {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
}