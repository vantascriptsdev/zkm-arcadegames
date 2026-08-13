import type { Card } from "./types";

export interface Suit {
  glyph: string;
  red: boolean;
}

const SUITS: Suit[] = [
  { glyph: "♠", red: false },
  { glyph: "♥", red: true },
  { glyph: "♦", red: true },
  { glyph: "♣", red: false }
];

const RANKS: Record<number, string> = {
  2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
  9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
};

export const CARD_MIN_VALUE = 2;

export const CARD_MAX_VALUE = 14;

export const SUIT_COUNT = SUITS.length;

export const RANK_COUNT = CARD_MAX_VALUE - CARD_MIN_VALUE + 1;

export const rankOf = (card: Card): string => RANKS[card.value];

export const suitOf = (card: Card): Suit => SUITS[card.suit] ?? SUITS[0];

export function randomCard(): Card {
  return {
    value: CARD_MIN_VALUE + Math.floor(Math.random() * RANK_COUNT),
    suit: Math.floor(Math.random() * SUIT_COUNT)
  };
}