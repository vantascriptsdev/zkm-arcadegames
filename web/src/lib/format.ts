import { BASE_MULTIPLIER } from "./types";

export type Tone = "win" | "loss" | "neutral";

const PLUS_SIGN = "+";
const HYPHEN_MINUS = "-";
const UNICODE_MINUS = "−";
const LARGE_MULTIPLIER = 1000;
const COORD_DECIMALS = 2;
const HEADING_DECIMALS = 1;
const DEGREE_SIGN = "°";
const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
const SECONDS_PER_DAY = 86400;
const MS_PER_SECOND = 1000;

export const money = (value: number): string =>
  "$" + Math.round(value).toLocaleString("en-US");

export const gain = (value: number): string => PLUS_SIGN + money(value);

export const loss = (value: number): string => HYPHEN_MINUS + money(value);

export const multiplier = (value: number): string => value.toFixed(2) + "x";

export const largeMultiplier = (value: number): string =>
  (value >= LARGE_MULTIPLIER
    ? Math.round(value).toLocaleString("en-US")
    : value.toFixed(2)) + "x";

export const coord = (value: number): string => value.toFixed(COORD_DECIMALS);

export const heading = (value: number): string =>
  value.toFixed(HEADING_DECIMALS) + DEGREE_SIGN;

export const since = (unixSeconds: number): string => {
  const elapsed = Math.max(0, Math.floor(Date.now() / MS_PER_SECOND) - unixSeconds);

  if (elapsed < SECONDS_PER_MINUTE) return "just now";
  if (elapsed < SECONDS_PER_HOUR) {
    return Math.floor(elapsed / SECONDS_PER_MINUTE) + "m ago";
  }
  if (elapsed < SECONDS_PER_DAY) return Math.floor(elapsed / SECONDS_PER_HOUR) + "h ago";

  return Math.floor(elapsed / SECONDS_PER_DAY) + "d ago";
};

export const amountTone = (text: string): Tone => {
  if (text.startsWith(PLUS_SIGN)) return "win";
  if (text.startsWith(HYPHEN_MINUS) || text.startsWith(UNICODE_MINUS)) return "loss";
  return "neutral";
};

export const multiplierTone = (text: string): Tone => {
  const value = Number.parseFloat(text);
  if (!Number.isFinite(value)) return "neutral";
  if (value > BASE_MULTIPLIER) return "win";
  if (value < BASE_MULTIPLIER) return "loss";
  return "neutral";
};