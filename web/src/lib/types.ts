export type GameId = "crash" | "plinko" | "hol" | "mines";

export const GAME_IDS = ["crash", "plinko", "hol", "mines"] as const;

export const GAME_LABELS: Record<GameId, string> = {
  crash: "Crash",
  plinko: "Plinko",
  hol: "Higher or Lower",
  mines: "Mines"
};

export function isGameId(value: unknown): value is GameId {
  return GAME_IDS.includes(value as GameId);
}

export type Phase = "idle" | "live" | "resolved";

export type RiskLevel = "LOW" | "MED" | "HIGH";

export const RISK_LABELS: Record<RiskLevel, string> = {
  LOW: "Low",
  MED: "Med",
  HIGH: "High"
};

export interface HistoryEntry {
  label: string;
  value?: string;
}

export interface GameSettings {
  minBet: number;
  maxBet: number;
  growthPerTick?: number;
  tickMs?: number;
  payouts?: Record<RiskLevel, number[]>;
  crashSpread?: number;
  tiles?: number;
  minBombs?: number;
  maxBombs?: number;
}

export type GameSettingsPayload = Partial<Record<GameId, Partial<GameSettings>>> & {
  houseEdge?: number;
};

export const TOTAL_LOSS_MULTIPLIER = 0;

export const BASE_MULTIPLIER = 1;

export type BetError =
  | "no_session"
  | "no_round"
  | "round_open"
  | "unknown_game"
  | "bad_bet"
  | "no_funds"
  | "bad_request"
  | "round_over"
  | "outcome_mismatch"
  | "bad_bombs"
  | "bad_tile";

export interface Card {
  value: number;
  suit: number;
}

export interface CrashOutcome {
  crashAt?: number;
}

export interface HolOutcome {
  card: Card;
}

export interface PlinkoOutcome {
  path: number[];
  slot: number;
  multiplier: number;
}

export interface MinesOutcome {
  tiles: number;
  bombs: number;
}

export interface MinesPick {
  tile: number;
  bomb: boolean;
  gems: number;
  multiplier: number;
  exhausted: boolean;
  bombTiles?: number[];
}

export interface Reveal {
  card: Card;
  correct: boolean;
  streak: number;
  multiplier: number;
  exhausted: boolean;
}

export interface BetResult<TOutcome = unknown> {
  ok: boolean;
  balance?: number;
  reason?: BetError;
  outcome?: TOutcome;
  bombTiles?: number[];
}

export interface RevealResult {
  ok: boolean;
  reason?: BetError;
  reveal?: Reveal;
}

export interface PickResult {
  ok: boolean;
  reason?: BetError;
  pick?: MinesPick;
}

export interface GameEngine {
  readonly phase: Phase;
  readonly busy: boolean;
  history: HistoryEntry[];
  primary(): void | Promise<void>;
  reset(): void;
  cleanup(): void;
}

export type ArcadeMode = "idle" | "play" | "spectate";

export interface ScreenRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Machine {
  id: string;
  game: GameId;
  x: number;
  y: number;
  z: number;
  heading: number;
  createdBy: string;
  createdAt: number;
  occupiedBy: string | null;
}

export function isOccupied(machine: Pick<Machine, "occupiedBy">): boolean {
  return machine.occupiedBy != null;
}

export type MachineFilter = GameId | "all";

export type MachineSortKey = "id" | "game" | "heading" | "state";

export type SortDirection = "asc" | "desc";

export type PlacementMode = "new" | "move";

export type PlacementStep = number;

export type AdminError =
  | "no_permission"
  | "unknown_machine"
  | "occupied"
  | "placement_open"
  | "bad_request";

export interface AdminResult {
  ok: boolean;
  reason?: AdminError;
}

export interface AdminMachinesResult {
  ok: boolean;
  reason?: AdminError;
  machines?: Machine[];
}

export type NuiInbound =
  | { action: "setConfig"; gameSettings?: GameSettingsPayload }
  | {
      action: "enterPlay";
      machineId: string;
      game?: GameId;
      rect?: ScreenRect | null;
      balance?: number;
      bet?: number;
      betMin?: number;
      betMax?: number;
      gameSettings?: GameSettingsPayload;
    }
  | { action: "exitPlay" }
  | { action: "setOccupied"; occupied: boolean }
  | { action: "crashBusted"; crashAt: number }
  | { action: "spectateSync"; game?: GameId; stake: number; roundLive: boolean }
  | { action: "spectateStake"; stake: number }
  | {
      action: "spectateRound";
      game?: GameId;
      bet: number;
      risk?: RiskLevel;
      outcome: SpectateOutcome;
    }
  | { action: "spectateReveal"; reveal: Reveal }
  | { action: "spectatePick"; pick: MinesPick }
  | { action: "spectateSettle"; multiplier: number; bombTiles?: number[] }
  | { action: "spectateBust"; crashAt: number }
  | { action: "spectateExit" }
  | { action: "adminOpen"; machines?: Machine[]; loading?: boolean }
  | { action: "adminMachines"; machines: Machine[] }
  | {
      action: "enterPlacement";
      mode: PlacementMode;
      machineId?: string | null;
      game: GameId;
      x: number;
      y: number;
      z: number;
      heading: number;
      step?: PlacementStep;
      valid?: boolean;
      reason?: string | null;
    }
  | { action: "placementTransform"; x: number; y: number; z: number; heading: number }
  | {
      action: "placementState";
      game?: GameId;
      step?: PlacementStep;
      valid?: boolean;
      reason?: string | null;
    }
  | { action: "exitPlacement" };

export type SpectateOutcome = CrashOutcome | HolOutcome | PlinkoOutcome | MinesOutcome;

export interface NuiOutboundMap {
  close: undefined;
  placeBet: { bet: number; risk?: RiskLevel; bombs?: number };
  reveal: { higher: boolean };
  pickTile: { tile: number };
  settle: { multiplier: number };
  setStake: { bet: number };
  exitPlay: undefined;
  playReady: { machineId: string };
  adminFetch: undefined;
  adminCreate: undefined;
  adminMove: { id: string };
  adminDelete: { id: string };
  adminTeleport: { id: string };
  adminClose: undefined;
}