import type { GameId, GameSettings, GameSettingsPayload, RiskLevel } from "../lib/types";
import { GAME_IDS } from "../lib/types";

const FALLBACK_MIN_BET = 100;
const FALLBACK_MAX_BET = 10000;

const FALLBACK_GROWTH_PER_TICK = 0.0075;
const FALLBACK_TICK_MS = 50;

const FALLBACK_TILES = 25;
const FALLBACK_MIN_BOMBS = 1;
const FALLBACK_MAX_BOMBS = 24;
const FALLBACK_HOUSE_EDGE = 0.95;
const DEFAULT_BOMBS = 3;

const FALLBACK_PAYOUTS: Record<RiskLevel, number[]> = {
  LOW: [6.04, 2.26, 1.51, 1.19, 1.08, 0.97, 0.54, 0.97, 1.08, 1.19, 1.51, 2.26, 6.04],
  MED: [28.27, 7.71, 2.57, 1.8, 1.16, 0.64, 0.39, 0.64, 1.16, 1.8, 2.57, 7.71, 28.27],
  HIGH: [162.94, 23, 7.76, 1.92, 0.67, 0.19, 0.19, 0.19, 0.67, 1.92, 7.76, 23, 162.94]
};

function defaultGameSettings(): Record<GameId, GameSettings> {
  return {
    crash: { minBet: FALLBACK_MIN_BET, maxBet: FALLBACK_MAX_BET },
    plinko: { minBet: FALLBACK_MIN_BET, maxBet: FALLBACK_MAX_BET },
    hol: { minBet: FALLBACK_MIN_BET, maxBet: FALLBACK_MAX_BET },
    mines: { minBet: FALLBACK_MIN_BET, maxBet: FALLBACK_MAX_BET }
  };
}

function positiveInteger(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return fallback;
  return Math.round(value);
}

function positiveNumber(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return fallback;
  return value;
}

export class Config {
  gameSettings = $state<Record<GameId, GameSettings>>(defaultGameSettings());
  houseEdge = $state(FALLBACK_HOUSE_EDGE);

  settingsFor(game: GameId): GameSettings {
    return this.gameSettings[game];
  }

  get crashGrowthPerTick() {
    return positiveNumber(this.gameSettings.crash.growthPerTick, FALLBACK_GROWTH_PER_TICK);
  }

  get crashTickMs() {
    return positiveInteger(this.gameSettings.crash.tickMs, FALLBACK_TICK_MS);
  }

  get plinkoPayouts(): Record<RiskLevel, number[]> {
    return this.gameSettings.plinko.payouts ?? FALLBACK_PAYOUTS;
  }

  get minesTiles() {
    return positiveInteger(this.gameSettings.mines.tiles, FALLBACK_TILES);
  }

  get minesMinBombs() {
    const floor = positiveInteger(this.gameSettings.mines.minBombs, FALLBACK_MIN_BOMBS);
    return Math.min(floor, this.minesTiles - 1);
  }

  get minesMaxBombs() {
    const ceiling = positiveInteger(this.gameSettings.mines.maxBombs, FALLBACK_MAX_BOMBS);
    return Math.max(this.minesMinBombs, Math.min(ceiling, this.minesTiles - 1));
  }

  get minesDefaultBombs() {
    return Math.max(this.minesMinBombs, Math.min(this.minesMaxBombs, DEFAULT_BOMBS));
  }

  applyGameSettings(payload: GameSettingsPayload) {
    const next = { ...this.gameSettings };

    for (const game of GAME_IDS) {
      const incoming = payload[game];
      if (!incoming || typeof incoming !== "object") continue;

      const current = next[game];
      const minBet = positiveInteger(incoming.minBet, current.minBet);
      const maxBet = positiveInteger(incoming.maxBet, current.maxBet);

      next[game] = {
        ...current,
        ...incoming,
        minBet: Math.min(minBet, maxBet),
        maxBet: Math.max(minBet, maxBet)
      };
    }

    this.gameSettings = next;
    this.houseEdge = positiveNumber(payload.houseEdge, this.houseEdge);
  }

  setLimits(game: GameId, minBet: number, maxBet: number) {
    this.applyGameSettings({ [game]: { minBet, maxBet } });
  }
}