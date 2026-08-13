import type {
  CrashOutcome,
  GameEngine,
  GameId,
  GameSettingsPayload,
  HolOutcome,
  MinesOutcome,
  NuiInbound,
  PlinkoOutcome
} from "../lib/types";
import { fetchNui, onNuiMessage } from "../lib/nui";
import { playBetTick } from "../lib/audio";
import { Admin } from "./admin.svelte";
import { Config } from "./config.svelte";
import { Session } from "./session.svelte";
import { CrashEngine } from "./crash.svelte";
import { PlinkoEngine, RISK_LEVELS } from "./plinko.svelte";
import { HolEngine } from "./hol.svelte";
import { MinesEngine } from "./mines.svelte";

const HEARTBEAT_INTERVAL_MS = 2000;

const BET_PUBLISH_INTERVAL_MS = 200;

const NO_PAYOUT = 0;

export class Arcade {
  readonly config = new Config();
  readonly session = new Session(this.config);
  readonly admin = new Admin();
  readonly crash = new CrashEngine(this.session);
  readonly plinko = new PlinkoEngine(this.session);
  readonly hol = new HolEngine(this.session);
  readonly mines = new MinesEngine(this.session);

  private engines: Record<GameId, GameEngine> = {
    crash: this.crash,
    plinko: this.plinko,
    hol: this.hol,
    mines: this.mines
  };

  private heartbeat: ReturnType<typeof setInterval> | null = null;

  private betPublishedAt = 0;
  private betPublishTimer: ReturnType<typeof setTimeout> | null = null;

  get active() {
    return this.engines[this.session.game];
  }

  get locked() {
    return this.active.busy || this.session.placing;
  }

  get primaryBlocked() {
    return this.session.placing || (this.active.phase === "idle" && !this.session.canAfford);
  }

  private clearHistory() {
    for (const engine of Object.values(this.engines)) engine.history = [];
  }

  private applyGame(game: GameId) {
    if (game === this.session.game) return;
    this.active.reset();
    this.session.game = game;
    this.session.limitBet();
  }

  private withBetTick(change: () => void) {
    const previousBet = this.session.bet;
    change();
    if (this.session.bet !== previousBet) playBetTick();
  }

  private sendBet() {
    this.betPublishedAt = Date.now();
    void fetchNui("setStake", { bet: this.session.bet });
  }

  private publishBet() {
    if (this.session.mode !== "play") return;
    if (this.betPublishTimer !== null) return;

    const sinceLast = Date.now() - this.betPublishedAt;

    if (sinceLast >= BET_PUBLISH_INTERVAL_MS) return this.sendBet();

    this.betPublishTimer = setTimeout(() => {
      this.betPublishTimer = null;
      if (this.session.mode !== "play") return;
      this.sendBet();
    }, BET_PUBLISH_INTERVAL_MS - sinceLast);
  }

  private stopPublish() {
    if (this.betPublishTimer === null) return;
    clearTimeout(this.betPublishTimer);
    this.betPublishTimer = null;
  }

  setBet(value: number) {
    if (this.locked) return;
    this.withBetTick(() => this.session.setBet(value));
  }

  dragBet(value: number) {
    if (this.locked) return;
    this.withBetTick(() => this.session.setBet(value));
  }

  stepBet(direction: 1 | -1) {
    if (this.locked) return;
    this.withBetTick(() => this.session.stepBet(direction));
  }

  stepBombs(direction: 1 | -1) {
    if (this.locked) return;
    const previous = this.mines.bombs;
    this.mines.stepBombs(direction);
    if (this.mines.bombs !== previous) playBetTick();
  }

  setBombs(value: number) {
    if (this.locked) return;
    const previous = this.mines.bombs;
    this.mines.setBombs(value);
    if (this.mines.bombs !== previous) playBetTick();
  }

  primary() {
    if (this.primaryBlocked) return;
    void this.active.primary();
  }

  back() {
    if (this.locked) return;
    if (this.active.phase === "resolved") return this.active.reset();
    this.close();
  }

  close() {
    if (this.session.mode === "play") {
      void fetchNui("exitPlay");
      return;
    }

    this.session.visible = false;
    void fetchNui("close");
  }

  private startHeartbeat(machineId: string) {
    this.stopHeartbeat();
    void fetchNui("playReady", { machineId });
    this.heartbeat = setInterval(
      () => void fetchNui("playReady", { machineId }),
      HEARTBEAT_INTERVAL_MS
    );
  }

  private stopHeartbeat() {
    if (this.heartbeat === null) return;
    clearInterval(this.heartbeat);
    this.heartbeat = null;
  }

  private applySessionPayload(message: {
    game?: GameId;
    gameSettings?: GameSettingsPayload;
    balance?: number;
    bet?: number;
    betMin?: number;
    betMax?: number;
  }) {
    if (message.game) this.applyGame(message.game);
    if (message.gameSettings) this.config.applyGameSettings(message.gameSettings);
    if (message.betMin !== undefined && message.betMax !== undefined) {
      this.session.setLimits(message.betMin, message.betMax);
    }
    if (message.balance !== undefined) this.session.balance = message.balance;
    if (message.bet !== undefined) this.session.setBet(message.bet);
    this.session.limitBet();
  }

  private enterPlay(message: Extract<NuiInbound, { action: "enterPlay" }>) {
    this.session.clearRoundBet();
    this.applySessionPayload(message);

    this.active.reset();
    this.clearHistory();
    this.session.machineId = message.machineId;
    this.session.rect = message.rect ?? null;
    this.session.occupied = false;
    this.session.spectateWaiting = false;
    this.session.mode = "play";
    this.session.visible = true;

    this.startHeartbeat(message.machineId);
    this.publishBet();
  }

  private exitPlay() {
    this.stopHeartbeat();
    this.stopPublish();
    this.active.reset();
    this.clearHistory();
    this.session.clearRoundBet();
    this.session.mode = "idle";
    this.session.machineId = null;
    this.session.rect = null;
    this.session.visible = this.session.surface === "dui";
  }

  private beginSpectating(game?: GameId) {
    if (game) this.applyGame(game);
    this.session.mode = "spectate";
  }

  private spectateSync(message: Extract<NuiInbound, { action: "spectateSync" }>) {
    this.beginSpectating(message.game);
    this.active.reset();
    this.session.spectateWaiting = message.roundLive;
    this.session.setBet(message.stake);
  }

  private spectateRound(message: Extract<NuiInbound, { action: "spectateRound" }>) {
    this.beginSpectating(message.game);
    this.session.spectateWaiting = false;
    this.session.setBet(message.bet);
    this.active.reset();

    if (this.session.game === "crash") {
      this.crash.startAt((message.outcome as CrashOutcome).crashAt);
    } else if (this.session.game === "plinko") {
      if (message.risk) this.plinko.setRisk(message.risk);
      this.plinko.dropWithOutcome(message.outcome as PlinkoOutcome);
    } else if (this.session.game === "mines") {
      this.mines.begin(message.outcome as MinesOutcome);
    } else {
      this.hol.dealCard((message.outcome as HolOutcome).card);
    }
  }

  private spectateSettle(message: Extract<NuiInbound, { action: "spectateSettle" }>) {
    if (!this.session.spectating) return;
    if (message.multiplier <= NO_PAYOUT) return;

    if (this.session.game === "crash") this.crash.cashOutAt(message.multiplier);
    else if (this.session.game === "hol") this.hol.cashOutAt(message.multiplier);
    else if (this.session.game === "mines") {
      this.mines.cashOutAt(message.multiplier, message.bombTiles);
    }
  }

  private spectateBust(message: Extract<NuiInbound, { action: "spectateBust" }>) {
    if (!this.session.spectating) return;
    if (this.session.game === "crash") this.crash.busted(message.crashAt);
  }

  private spectateExit() {
    if (!this.session.spectating) return;

    this.active.reset();
    this.clearHistory();
    this.session.spectateWaiting = false;
    this.session.mode = "idle";
    this.session.limitBet();
  }

  handleKey(event: KeyboardEvent) {
    if (this.admin.surface !== "none") return this.admin.handleKey(event);
    if (!this.session.visible || !this.session.interactive) return;
    const key = event.key.toLowerCase();
    const game = this.session.game;

    if (key === "e" || key === "enter") {
      event.preventDefault();
      this.primary();
    } else if (key === "arrowup") {
      event.preventDefault();
      this.stepBet(1);
    } else if (key === "arrowdown") {
      event.preventDefault();
      this.stepBet(-1);
    } else if (key === "arrowleft") {
      event.preventDefault();
      if (game === "mines") this.stepBombs(-1);
      else this.setBet(this.session.betMin);
    } else if (key === "arrowright") {
      event.preventDefault();
      if (game === "mines") this.stepBombs(1);
      else this.setBet(this.session.betMax);
    } else if (key === "backspace" || key === "escape") {
      event.preventDefault();
      this.back();
    } else if (key === "w" && game === "hol" && this.hol.higherCount > 0) {
      void this.hol.guess(true);
    } else if (key === "s" && game === "hol" && this.hol.lowerCount > 0) {
      void this.hol.guess(false);
    } else if (game === "plinko" && ["1", "2", "3"].includes(key)) {
      this.plinko.setRisk(RISK_LEVELS[Number(key) - 1]);
    }
  }

  applyNuiMessage(message: NuiInbound) {
    if (this.admin.apply(message)) return;

    switch (message.action) {
      case "setConfig":
        if (message.gameSettings) this.config.applyGameSettings(message.gameSettings);
        this.session.limitBet();
        break;
      case "enterPlay":
        this.enterPlay(message);
        break;
      case "exitPlay":
        this.exitPlay();
        break;
      case "crashBusted":
        this.crash.busted(message.crashAt);
        break;
      case "setOccupied":
        this.session.occupied = message.occupied;
        break;
      case "spectateSync":
        this.spectateSync(message);
        break;
      case "spectateStake":
        this.beginSpectating();
        this.session.setBet(message.stake);
        break;
      case "spectateRound":
        this.spectateRound(message);
        break;
      case "spectateReveal":
        if (this.session.spectating) this.hol.applyReveal(message.reveal);
        break;
      case "spectatePick":
        if (this.session.spectating) this.mines.applyPick(message.pick);
        break;
      case "spectateSettle":
        this.spectateSettle(message);
        break;
      case "spectateBust":
        this.spectateBust(message);
        break;
      case "spectateExit":
        this.spectateExit();
        break;
    }
  }

  mount(): () => void {
    const onKeyDown = (event: KeyboardEvent) => this.handleKey(event);
    window.addEventListener("keydown", onKeyDown);
    const offMessage = onNuiMessage((message) => this.applyNuiMessage(message));
    this.session.onBetChange = () => this.publishBet();

    return () => {
      window.removeEventListener("keydown", onKeyDown);
      offMessage();
      this.session.onBetChange = null;
      this.stopHeartbeat();
      this.stopPublish();
      this.admin.cleanup();
      for (const engine of Object.values(this.engines)) engine.cleanup();
    };
  }
}