import type {
  AdminError,
  AdminMachinesResult,
  AdminResult,
  GameId,
  Machine,
  MachineFilter,
  MachineSortKey,
  NuiInbound,
  PlacementMode,
  PlacementStep,
  SortDirection
} from "../lib/types";
import { GAME_IDS, GAME_LABELS, isOccupied } from "../lib/types";
import { fetchNui, inNui } from "../lib/nui";

export type AdminSurface = "none" | "manager" | "placement";

const NOTICE_DURATION_MS = 2600;
const PREVIEW_RELOAD_DELAY_MS = 320;

const ALL_FILTER: MachineFilter = "all";

const ERROR_MESSAGES: Record<AdminError, string> = {
  no_permission: "You do not have permission for that.",
  unknown_machine: "That machine no longer exists.",
  occupied: "That machine is in use.",
  placement_open: "Finish the current placement first.",
  bad_request: "That request was rejected."
};

const UNREACHABLE_MESSAGE = "The server did not respond.";

const PREVIEW_MACHINES: Machine[] = [
  {
    id: "0041",
    game: "crash",
    x: -412.86,
    y: 31.2,
    z: 812.44,
    heading: 274.5,
    createdBy: "vex.admin",
    createdAt: Math.floor(Date.now() / 1000) - 262800,
    occupiedBy: null
  },
  {
    id: "0042",
    game: "plinko",
    x: -398.1,
    y: 31.2,
    z: 806.92,
    heading: 90,
    createdBy: "vex.admin",
    createdAt: Math.floor(Date.now() / 1000) - 262800,
    occupiedBy: "duskrider"
  },
  {
    id: "0043",
    game: "hol",
    x: -386.44,
    y: 31.2,
    z: 819.05,
    heading: 180,
    createdBy: "vex.admin",
    createdAt: Math.floor(Date.now() / 1000) - 259200,
    occupiedBy: null
  },
  {
    id: "0044",
    game: "mines",
    x: -374.02,
    y: 31.2,
    z: 806.1,
    heading: 0,
    createdBy: "kestrel",
    createdAt: Math.floor(Date.now() / 1000) - 68400,
    occupiedBy: null
  },
  {
    id: "0045",
    game: "crash",
    x: 108.55,
    y: 74.8,
    z: -221.36,
    heading: 315,
    createdBy: "kestrel",
    createdAt: Math.floor(Date.now() / 1000) - 68400,
    occupiedBy: "ninefold"
  },
  {
    id: "0046",
    game: "mines",
    x: 112.9,
    y: 74.8,
    z: -214.72,
    heading: 45,
    createdBy: "kestrel",
    createdAt: Math.floor(Date.now() / 1000) - 39600,
    occupiedBy: null
  },
  {
    id: "0047",
    game: "plinko",
    x: 640.18,
    y: 12.05,
    z: 402.88,
    heading: 202.5,
    createdBy: "orla.dev",
    createdAt: Math.floor(Date.now() / 1000) - 7200,
    occupiedBy: null
  }
];

function compare(left: number | string, right: number | string): number {
  if (typeof left === "number" && typeof right === "number") return left - right;
  return String(left).localeCompare(String(right));
}

function idKey(id: string): number | string {
  const numeric = Number(id);
  return Number.isFinite(numeric) ? numeric : id;
}

export class Admin {
  surface = $state<AdminSurface>("none");
  machines = $state<Machine[]>(inNui ? [] : PREVIEW_MACHINES);
  loading = $state(false);
  busy = $state(false);
  notice = $state<string | null>(null);

  filter = $state<MachineFilter>(ALL_FILTER);
  query = $state("");
  sortKey = $state<MachineSortKey>("id");
  sortDirection = $state<SortDirection>("asc");
  confirmId = $state<string | null>(null);
  blockedId = $state<string | null>(null);

  mode = $state<PlacementMode>("new");
  placingId = $state<string | null>(null);
  placingGame = $state<GameId>("crash");
  step = $state<PlacementStep>(0.5);
  valid = $state(true);
  invalidReason = $state<string | null>(null);

  x = $state(0);
  y = $state(0);
  z = $state(0);
  heading = $state(0);

  private noticeTimer: ReturnType<typeof setTimeout> | null = null;

  counts = $derived.by(() => {
    const totals: Record<string, number> = { [ALL_FILTER]: this.machines.length };

    for (const game of GAME_IDS) totals[game] = 0;
    for (const machine of this.machines) totals[machine.game] += 1;

    return totals;
  });

  chips = $derived([
    { id: ALL_FILTER, label: "All", count: this.counts[ALL_FILTER] },
    ...GAME_IDS.map((game) => ({
      id: game,
      label: GAME_LABELS[game],
      count: this.counts[game]
    }))
  ]);

  rows = $derived.by(() => {
    const needle = this.query.trim().toLowerCase();
    const direction = this.sortDirection === "desc" ? -1 : 1;

    const matched = this.machines.filter((machine) => {
      if (this.filter !== ALL_FILTER && machine.game !== this.filter) return false;
      if (needle === "") return true;

      const haystack = `${machine.id} ${GAME_LABELS[machine.game]} ${machine.createdBy}`;

      return haystack.toLowerCase().includes(needle);
    });

    return matched.sort((left, right) => {
      if (this.sortKey === "id") {
        return compare(idKey(left.id), idKey(right.id)) * direction;
      }
      if (this.sortKey === "heading") return (left.heading - right.heading) * direction;
      if (this.sortKey === "state") {
        const leftState = isOccupied(left) ? 1 : 0;
        const rightState = isOccupied(right) ? 1 : 0;
        return (leftState - rightState) * direction;
      }
      return compare(GAME_LABELS[left.game], GAME_LABELS[right.game]) * direction;
    });
  });

  occupiedCount = $derived(this.machines.filter(isOccupied).length);

  get isEmpty() {
    return !this.loading && this.machines.length === 0;
  }

  get modeLabel() {
    if (this.mode === "move") return `Moving machine ${this.placingId ?? ""}`.trim();
    return "Placing new machine";
  }

  get validityLabel() {
    if (!this.valid) return this.invalidReason ?? "Position rejected";
    return this.mode === "move" ? "Ready to save" : "Ready to place";
  }

  get stepLabel() {
    return `${this.step.toFixed(2)}m`;
  }

  private flash(message: string) {
    this.notice = message;
    if (this.noticeTimer !== null) clearTimeout(this.noticeTimer);
    this.noticeTimer = setTimeout(() => {
      this.notice = null;
    }, NOTICE_DURATION_MS);
  }

  private report(result: AdminResult | null): boolean {
    if (!result) {
      this.flash(UNREACHABLE_MESSAGE);
      return false;
    }
    if (!result.ok) {
      this.flash(ERROR_MESSAGES[result.reason ?? "bad_request"]);
      return false;
    }
    return true;
  }

  private clearPrompts() {
    this.confirmId = null;
    this.blockedId = null;
  }

  setFilter(filter: string) {
    this.filter = filter === ALL_FILTER ? ALL_FILTER : (filter as GameId);
    this.clearPrompts();
  }

  setQuery(query: string) {
    this.query = query;
    this.clearPrompts();
  }

  sort(key: MachineSortKey) {
    if (this.sortKey === key) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortKey = key;
      this.sortDirection = "asc";
    }
    this.clearPrompts();
  }

  askDelete(id: string) {
    this.blockedId = null;
    this.confirmId = this.confirmId === id ? null : id;
  }

  dismissPrompt() {
    this.clearPrompts();
  }

  async reload() {
    if (this.busy) return;

    this.clearPrompts();
    this.busy = true;
    this.loading = true;
    this.machines = [];

    if (!inNui) {
      await new Promise((resolve) => setTimeout(resolve, PREVIEW_RELOAD_DELAY_MS));
      this.machines = PREVIEW_MACHINES;
      this.busy = false;
      this.loading = false;
      return;
    }

    const result = await fetchNui<"adminFetch", AdminMachinesResult>("adminFetch");

    this.busy = false;
    this.loading = false;

    if (!this.report(result)) return;
    if (result?.machines) this.machines = result.machines;
  }

  async create() {
    if (this.busy) return;

    this.clearPrompts();

    if (!inNui) return;

    this.busy = true;
    const result = await fetchNui<"adminCreate", AdminResult>("adminCreate");
    this.busy = false;

    this.report(result);
  }

  async move(id: string) {
    if (this.busy) return;

    this.clearPrompts();

    if (!inNui) return;

    this.busy = true;
    const result = await fetchNui<"adminMove", AdminResult>("adminMove", { id });
    this.busy = false;

    this.report(result);
  }

  async teleport(id: string) {
    if (this.busy) return;
    if (!inNui) return;

    this.busy = true;
    const result = await fetchNui<"adminTeleport", AdminResult>("adminTeleport", { id });
    this.busy = false;

    this.report(result);
  }

  async remove(id: string) {
    if (this.busy) return;

    if (!inNui) {
      this.machines = this.machines.filter((machine) => machine.id !== id);
      this.clearPrompts();
      return;
    }

    this.busy = true;
    const result = await fetchNui<"adminDelete", AdminResult>("adminDelete", { id });
    this.busy = false;

    this.confirmId = null;

    if (result && !result.ok && result.reason === "occupied") {
      this.blockedId = id;
      return;
    }

    if (!this.report(result)) return;

    this.machines = this.machines.filter((machine) => machine.id !== id);
  }

  close() {
    this.surface = "none";
    this.clearPrompts();
    void fetchNui("adminClose");
  }

  handleKey(event: KeyboardEvent) {
    if (this.surface !== "manager") return;
    if (event.key !== "Escape") return;

    event.preventDefault();

    if (this.confirmId !== null || this.blockedId !== null) return this.clearPrompts();

    this.close();
  }

  private openManager(message: Extract<NuiInbound, { action: "adminOpen" }>) {
    this.clearPrompts();
    this.query = "";
    this.filter = ALL_FILTER;
    this.notice = null;
    this.loading = message.loading ?? false;
    if (message.machines) this.machines = message.machines;
    this.surface = "manager";
  }

  private enterPlacement(message: Extract<NuiInbound, { action: "enterPlacement" }>) {
    this.clearPrompts();
    this.mode = message.mode;
    this.placingId = message.machineId ?? null;
    this.placingGame = message.game;
    this.step = message.step ?? 0.5;
    this.valid = message.valid ?? true;
    this.invalidReason = message.reason ?? null;
    this.x = message.x;
    this.y = message.y;
    this.z = message.z;
    this.heading = message.heading;
    this.surface = "placement";
  }

  private applyPlacementState(
    message: Extract<NuiInbound, { action: "placementState" }>
  ) {
    if (message.game !== undefined) this.placingGame = message.game;
    if (message.step !== undefined) this.step = message.step;
    if (message.valid !== undefined) this.valid = message.valid;
    if (message.reason !== undefined) this.invalidReason = message.reason;
  }

  apply(message: NuiInbound): boolean {
    switch (message.action) {
      case "adminOpen":
        this.openManager(message);
        return true;
      case "adminMachines":
        this.machines = message.machines;
        this.loading = false;
        return true;
      case "enterPlacement":
        this.enterPlacement(message);
        return true;
      case "placementTransform":
        this.x = message.x;
        this.y = message.y;
        this.z = message.z;
        this.heading = message.heading;
        return true;
      case "placementState":
        this.applyPlacementState(message);
        return true;
      case "exitPlacement":
        if (this.surface === "placement") this.surface = "none";
        return true;
      default:
        return false;
    }
  }

  cleanup() {
    if (this.noticeTimer === null) return;
    clearTimeout(this.noticeTimer);
    this.noticeTimer = null;
  }
}
