import type {
  ArcadeMode,
  BetError,
  BetResult,
  GameId,
  MinesPick,
  PickResult,
  Reveal,
  RevealResult,
  RiskLevel,
  ScreenRect
} from "../lib/types";
import { fetchNui, inNui, initialGame, surface } from "../lib/nui";
import type { Config } from "./config.svelte";

const HIGH_BET_THRESHOLD = 5000;
const MID_BET_THRESHOLD = 1000;
const HIGH_BET_STEP = 1000;
const MID_BET_STEP = 500;
const LOW_BET_STEP = 100;

const BROWSER_PREVIEW_BALANCE = 48250;
const NOTICE_DURATION_MS = 2600;

const ERROR_MESSAGES: Record<BetError, string> = {
  no_session: "Machine is not ready.",
  no_round: "There is no bet to settle.",
  round_open: "A bet is already in play.",
  unknown_game: "This machine is out of order.",
  bad_bet: "That bet is outside the machine limits.",
  no_funds: "Not enough cash for that bet.",
  bad_request: "This machine could not start the round.",
  round_over: "That round has already finished.",
  outcome_mismatch: "The machine rejected that result.",
  bad_bombs: "That bomb count is outside the machine limits.",
  bad_tile: "That tile cannot be picked."
};

const UNREACHABLE_MESSAGE = "The machine did not respond.";

export class Session {
  readonly surface = surface;

  readonly config: Config;

  game = $state<GameId>(initialGame ?? "mines");
  balance = $state(inNui ? 0 : BROWSER_PREVIEW_BALANCE);
  bet = $state(1000);
  visible = $state(surface === "dui" || !inNui);
  showHistory = $state(true);

  mode = $state<ArcadeMode>("idle");
  machineId = $state<string | null>(null);
  rect = $state<ScreenRect | null>(null);
  occupied = $state(false);
  spectateWaiting = $state(false);

  roundBet = $state(0);
  placing = $state(false);
  notice = $state<string | null>(null);

  private noticeTimer: ReturnType<typeof setTimeout> | null = null;

  onBetChange: (() => void) | null = null;

  constructor(config: Config) {
    this.config = config;
    this.limitBet();
  }

  get interactive() {
    return this.mode === "play";
  }

  get spectating() {
    return this.mode === "spectate";
  }

  get showOccupiedOverlay() {
    if (!this.occupied || this.mode === "play") return false;
    return !this.spectating;
  }

  get showBalance() {
    return this.mode === "play" || !inNui;
  }

  get betMin() {
    return this.config.settingsFor(this.game).minBet;
  }

  get spendable() {
    if (this.spectating) return this.config.settingsFor(this.game).maxBet;
    return this.balance + this.roundBet;
  }

  get betMax() {
    const ceiling = this.config.settingsFor(this.game).maxBet;
    return Math.max(this.betMin, Math.min(ceiling, this.spendable));
  }

  get canAfford() {
    return this.spendable >= this.betMin;
  }

  get betFraction() {
    return this.betMax === this.betMin
      ? 0
      : (this.bet - this.betMin) / (this.betMax - this.betMin);
  }

  setBet(value: number) {
    const next = Math.max(this.betMin, Math.min(this.betMax, Math.round(value)));

    if (next === this.bet) return;

    this.bet = next;
    this.onBetChange?.();
  }

  stepBet(direction: 1 | -1) {
    const step =
      this.bet >= HIGH_BET_THRESHOLD
        ? HIGH_BET_STEP
        : this.bet >= MID_BET_THRESHOLD
          ? MID_BET_STEP
          : LOW_BET_STEP;
    this.setBet(this.bet + direction * step);
  }

  setLimits(minimum: number, maximum: number) {
    this.config.setLimits(this.game, minimum, maximum);
    this.limitBet();
  }

  limitBet() {
    this.setBet(this.bet);
  }

  flash(message: string) {
    this.notice = message;
    if (this.noticeTimer !== null) clearTimeout(this.noticeTimer);
    this.noticeTimer = setTimeout(() => {
      this.notice = null;
    }, NOTICE_DURATION_MS);
  }

  async placeBet<TOutcome>(
    previewOutcome: () => TOutcome,
    options?: { risk?: RiskLevel; bombs?: number }
  ): Promise<TOutcome | null> {
    if (this.spectating) return null;
    if (this.placing || this.roundBet !== 0) return null;

    if (this.bet < this.betMin || this.bet > this.betMax) {
      this.flash(ERROR_MESSAGES.bad_bet);
      return null;
    }

    if (!inNui) {
      this.roundBet = this.bet;
      this.balance -= this.bet;
      return previewOutcome();
    }

    this.placing = true;

    let result: BetResult<TOutcome> | null;

    try {
      result = await fetchNui<"placeBet", BetResult<TOutcome>>("placeBet", {
        bet: this.bet,
        risk: options?.risk,
        bombs: options?.bombs
      });
    } finally {
      this.placing = false;
    }

    if (!result) {
      this.flash(UNREACHABLE_MESSAGE);
      return null;
    }

    if (!result.ok || !result.outcome) {
      this.flash(ERROR_MESSAGES[result.reason ?? "no_session"]);
      return null;
    }

    this.roundBet = this.bet;
    if (result.balance !== undefined) this.balance = result.balance;

    return result.outcome;
  }

  async reveal(higher: boolean, previewReveal: () => Reveal): Promise<Reveal | null> {
    if (this.spectating) return null;
    if (!inNui) return previewReveal();

    const result = await fetchNui<"reveal", RevealResult>("reveal", { higher });

    if (!result) {
      this.flash(UNREACHABLE_MESSAGE);
      return null;
    }

    if (!result.ok || !result.reveal) {
      this.flash(ERROR_MESSAGES[result.reason ?? "no_round"]);
      return null;
    }

    return result.reveal;
  }

  async pick(tile: number, previewPick: () => MinesPick): Promise<MinesPick | null> {
    if (this.spectating) return null;
    if (!inNui) return previewPick();

    const result = await fetchNui<"pickTile", PickResult>("pickTile", { tile });

    if (!result) {
      this.flash(UNREACHABLE_MESSAGE);
      return null;
    }

    if (!result.ok || !result.pick) {
      this.flash(ERROR_MESSAGES[result.reason ?? "no_round"]);
      return null;
    }

    return result.pick;
  }

  async settle(multiplier: number): Promise<BetResult | null> {
    const bet = this.roundBet;

    if (this.spectating) return null;
    if (bet === 0) return null;

    this.roundBet = 0;

    if (!inNui) {
      this.balance += Math.round(bet * multiplier);
      this.limitBet();
      return null;
    }

    const result = await fetchNui<"settle", BetResult>("settle", { multiplier });

    if (!result) {
      this.flash(UNREACHABLE_MESSAGE);
      return null;
    }

    if (!result.ok) this.flash(ERROR_MESSAGES[result.reason ?? "no_round"]);
    if (result.balance !== undefined) this.balance = result.balance;

    this.limitBet();

    return result;
  }

  clearRoundBet() {
    this.roundBet = 0;
    this.placing = false;
    this.notice = null;
    if (this.noticeTimer !== null) clearTimeout(this.noticeTimer);
    this.limitBet();
  }
}