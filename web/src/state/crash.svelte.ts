import type { CrashOutcome, GameEngine, HistoryEntry, Phase } from "../lib/types";
import { TOTAL_LOSS_MULTIPLIER } from "../lib/types";
import { multiplier as formatMultiplier } from "../lib/format";
import { inNui } from "../lib/nui";
import type { Session } from "./session.svelte";
import { playCrashMilestone, playLoss, playRoundStart, playWin } from "../lib/audio";

const TRACE_POINTS = 80;
const HISTORY_LIMIT = 6;
const MIN_CRASH_POINT = 1.01;
const PREVIEW_CRASH_SPREAD = 0.97;
const FIRST_MILESTONE = 1.5;
const MILESTONE_STEP = 0.5;

export class CrashEngine implements GameEngine {
  private readonly session: Session;

  phase = $state<Phase>("idle");
  multiplier = $state(1);
  cashed = $state(false);
  trace = $state<number[]>([1]);
  history = $state<HistoryEntry[]>([]);

  private crashAt: number | null = null;
  private milestonesPlayed = 0;
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor(session: Session) {
    this.session = session;
  }

  get busy() {
    return this.phase === "live";
  }

  async primary() {
    if (this.phase === "resolved") return this.reset();
    if (this.phase === "live") return this.cashOut();
    await this.start();
  }

  async start() {
    const outcome = await this.session.placeBet<CrashOutcome>(() => ({
      crashAt: previewCrashPoint(this.session.config.houseEdge)
    }));

    if (!outcome) return;

    this.startAt(outcome.crashAt);
  }

  startAt(crashAt?: number) {
    this.cleanup();
    this.crashAt = crashAt === undefined ? null : Math.max(MIN_CRASH_POINT, crashAt);
    this.phase = "live";
    this.multiplier = 1;
    this.cashed = false;
    this.trace = [1];
    this.milestonesPlayed = 0;
    playRoundStart();

    this.timer = setInterval(() => this.tick(), this.session.config.crashTickMs);
  }

  private tick() {
    const next = this.multiplier * (1 + this.session.config.crashGrowthPerTick);
    if (this.crashAt !== null && next >= this.crashAt) return this.busted(this.crashAt);
    this.multiplier = next;
    this.appendTrace(next);
    this.announceMilestone(next);
  }

  private announceMilestone(value: number) {
    const reached = Math.floor((value - FIRST_MILESTONE) / MILESTONE_STEP) + 1;
    if (reached <= this.milestonesPlayed) return;
    this.milestonesPlayed = reached;
    playCrashMilestone(reached - 1);
  }

  private appendTrace(value: number) {
    this.trace.push(value);
    if (this.trace.length > TRACE_POINTS) this.trace.shift();
  }

  cashOut() {
    if (this.phase !== "live") return;
    const multiplier = this.multiplier;
    this.cashOutAt(multiplier);
    void this.session.settle(multiplier);
  }

  cashOutAt(multiplier: number) {
    if (this.phase !== "live") return;
    this.cleanup();
    this.phase = "resolved";
    this.cashed = true;
    this.multiplier = multiplier;
    this.appendTrace(multiplier);
    this.record(formatMultiplier(multiplier));
    playWin();
  }

  busted(crashAt: number) {
    if (this.phase !== "live") return;
    this.cleanup();
    this.phase = "resolved";
    this.cashed = false;
    this.multiplier = crashAt;
    this.appendTrace(crashAt);
    this.record(formatMultiplier(crashAt));
    playLoss();

    if (inNui) this.session.clearRoundBet();
    else void this.session.settle(TOTAL_LOSS_MULTIPLIER);
  }

  private record(label: string, value?: string) {
    this.history = [{ label, value }, ...this.history].slice(0, HISTORY_LIMIT);
  }

  reset() {
    this.cleanup();
    this.phase = "idle";
    this.multiplier = 1;
    this.cashed = false;
    this.trace = [1];
  }

  cleanup() {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
}

function previewCrashPoint(houseEdge: number): number {
  return Math.max(MIN_CRASH_POINT, (1 / (1 - Math.random() * PREVIEW_CRASH_SPREAD)) * houseEdge);
}