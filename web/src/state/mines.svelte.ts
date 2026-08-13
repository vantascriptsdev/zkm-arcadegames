import type { GameEngine, HistoryEntry, MinesOutcome, MinesPick, Phase } from "../lib/types";
import { BASE_MULTIPLIER, TOTAL_LOSS_MULTIPLIER } from "../lib/types";
import { gain, loss } from "../lib/format";
import type { Session } from "./session.svelte";
import { playGemReveal, playLoss, playRoundStart, playWin } from "../lib/audio";

const HISTORY_LIMIT = 4;
const FIRST_PICK = 1;

function minesMultiplier(
  picks: number,
  bombs: number,
  tiles: number,
  houseEdge: number
): number {
  let multiplier = houseEdge;

  for (let index = 0; index < picks; index += 1) {
    multiplier *= (tiles - index) / (tiles - bombs - index);
  }

  return multiplier;
}

export class MinesEngine implements GameEngine {
  private readonly session: Session;

  phase = $state<Phase>("idle");
  bombs = $state(0);
  gems = $state<number[]>([]);
  bombTiles = $state<number[]>([]);
  hitTile = $state<number | null>(null);
  multiplier = $state(BASE_MULTIPLIER);
  won = $state(false);
  picking = $state(false);
  history = $state<HistoryEntry[]>([]);

  private roundBombs = 0;

  private previewBombs: number[] | null = null;

  constructor(session: Session) {
    this.session = session;
    this.bombs = session.config.minesDefaultBombs;
  }

  get busy() {
    return this.phase === "live";
  }

  get tiles() {
    return this.session.config.minesTiles;
  }

  get activeBombs() {
    return this.phase === "idle" ? this.bombs : this.roundBombs;
  }

  get safeTiles() {
    return this.tiles - this.activeBombs;
  }

  get gemCount() {
    return this.gems.length;
  }

  get remaining() {
    return this.safeTiles - this.gemCount;
  }

  get cashValue() {
    return this.session.bet * this.multiplier;
  }

  get canCashOut() {
    return this.phase === "live" && this.gemCount > 0;
  }

  get houseEdgeMultiplier() {
    return this.multiplierAt(0);
  }

  get reachedMultiplier() {
    return this.multiplierAt(this.gemCount);
  }

  get revealed() {
    return this.phase === "resolved";
  }

  multiplierAt(picks: number) {
    return minesMultiplier(picks, this.activeBombs, this.tiles, this.session.config.houseEdge);
  }

  get nextMultiplier() {
    return this.multiplierAt(this.gemCount + FIRST_PICK);
  }

  setBombs(value: number) {
    if (this.phase === "live") return;
    const { minesMinBombs, minesMaxBombs } = this.session.config;
    this.bombs = Math.max(minesMinBombs, Math.min(minesMaxBombs, Math.round(value)));
  }

  stepBombs(direction: 1 | -1) {
    this.setBombs(this.bombs + direction);
  }

  async primary() {
    if (this.picking) return;
    if (this.phase === "resolved") return this.reset();
    if (this.phase === "live") return this.cashOut();
    await this.start();
  }

  async start() {
    const outcome = await this.session.placeBet<MinesOutcome>(
      () => ({ tiles: this.tiles, bombs: this.bombs }),
      { bombs: this.bombs }
    );

    if (!outcome) return;

    this.begin(outcome);
  }

  begin(outcome: MinesOutcome) {
    this.roundBombs = outcome.bombs;
    this.phase = "live";
    this.gems = [];
    this.bombTiles = [];
    this.hitTile = null;
    this.multiplier = this.houseEdgeMultiplier;
    this.won = false;
    this.previewBombs = null;
    playRoundStart();
  }

  async pick(tile: number) {
    if (this.phase !== "live" || this.picking) return;
    if (this.gems.includes(tile)) return;

    this.picking = true;
    const pick = await this.session.pick(tile, () => this.previewPick(tile));
    this.picking = false;

    if (!pick || this.phase !== "live") return;

    this.applyPick(pick);
  }

  applyPick(pick: MinesPick) {
    if (pick.bomb) {
      this.multiplier = this.reachedMultiplier;
      this.hitTile = pick.tile;
      this.bombTiles = pick.bombTiles ?? [pick.tile];
      this.phase = "resolved";
      this.won = false;
      playLoss();
      this.record("Bust on " + (this.gemCount + FIRST_PICK), loss(this.session.bet));
      void this.session.settle(TOTAL_LOSS_MULTIPLIER);
      return;
    }

    this.gems = [...this.gems, pick.tile];
    this.multiplier = pick.multiplier;
    playGemReveal(this.gemCount);

    if (pick.exhausted) {
      if (pick.bombTiles) this.bombTiles = pick.bombTiles;
      this.clear(pick.multiplier);
    }
  }

  private clear(multiplier: number) {
    this.phase = "resolved";
    this.won = true;
    this.multiplier = multiplier;
    playWin();
    this.record("Cleared board", gain(this.session.bet * multiplier));
    void this.settleAndReveal(multiplier);
  }

  async cashOut() {
    if (!this.canCashOut) return;

    const multiplier = this.multiplier;
    const gems = this.gemCount;

    this.phase = "resolved";
    this.won = true;
    playWin();
    this.record("Cashed " + gems + " gems", gain(this.session.bet * multiplier));

    await this.settleAndReveal(multiplier);
  }

  private async settleAndReveal(multiplier: number) {
    const result = await this.session.settle(multiplier);

    if (result?.bombTiles) this.bombTiles = result.bombTiles;
    else if (this.previewBombs) this.bombTiles = this.previewBombs;
  }

  cashOutAt(multiplier: number, bombTiles?: number[]) {
    if (this.phase !== "live") return;
    this.multiplier = multiplier;
    this.phase = "resolved";
    this.won = true;
    if (bombTiles) this.bombTiles = bombTiles;
    playWin();
  }

  private record(label: string, value?: string) {
    this.history = [{ label, value }, ...this.history].slice(0, HISTORY_LIMIT);
  }

  private previewPick(tile: number): MinesPick {
    if (!this.previewBombs) this.previewBombs = this.rollPreviewBombs();

    const bomb = this.previewBombs.includes(tile);
    const gems = bomb ? this.gemCount : this.gemCount + FIRST_PICK;

    return {
      tile,
      bomb,
      gems,
      multiplier: bomb ? TOTAL_LOSS_MULTIPLIER : this.multiplierAt(gems),
      exhausted: !bomb && gems >= this.safeTiles,
      bombTiles: bomb ? this.previewBombs : undefined
    };
  }

  private rollPreviewBombs(): number[] {
    const pool = Array.from({ length: this.tiles }, (_unused, index) => index);

    for (let index = pool.length - 1; index > 0; index -= 1) {
      const swap = Math.floor(Math.random() * (index + 1));
      [pool[index], pool[swap]] = [pool[swap], pool[index]];
    }

    return pool.slice(0, this.activeBombs);
  }

  reset() {
    this.phase = "idle";
    this.gems = [];
    this.bombTiles = [];
    this.hitTile = null;
    this.won = false;
    this.picking = false;
    this.previewBombs = null;
    this.setBombs(this.bombs);
    this.multiplier = this.houseEdgeMultiplier;
  }

  cleanup() {}
}