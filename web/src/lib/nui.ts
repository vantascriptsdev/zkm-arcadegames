import type { GameId, NuiInbound, NuiOutboundMap } from "./types";
import { isGameId } from "./types";

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    invokeNative?: unknown;
  }
}

const DEFAULT_RESOURCE_NAME = "zkm-arcadegames";

const CALLBACK_TIMEOUT_MS = 5000;

export const inNui =
  typeof window !== "undefined" && typeof window.invokeNative !== "undefined";

const urlParams =
  typeof window !== "undefined"
    ? new URLSearchParams(window.location.search)
    : new URLSearchParams();

export const surface: "dui" | "nui" = urlParams.get("surface") === "dui" ? "dui" : "nui";

export const initialGame: GameId | null = (() => {
  const game = urlParams.get("game");
  return isGameId(game) ? game : null;
})();

function resourceName(): string {
  return window.GetParentResourceName?.() ?? DEFAULT_RESOURCE_NAME;
}

export async function fetchNui<K extends keyof NuiOutboundMap, T = unknown>(
  event: K,
  data?: NuiOutboundMap[K]
): Promise<T | null> {
  if (!inNui) return null;
  try {
    const response = await fetch(`https://${resourceName()}/${event}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data ?? {}),
      signal: AbortSignal.timeout(CALLBACK_TIMEOUT_MS)
    });
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

export function onNuiMessage(handler: (message: NuiInbound) => void): () => void {
  const listener = (event: MessageEvent) => {
    const message = event.data;
    if (message && typeof message === "object" && typeof message.action === "string") {
      handler(message as NuiInbound);
    }
  };
  window.addEventListener("message", listener);
  return () => window.removeEventListener("message", listener);
}