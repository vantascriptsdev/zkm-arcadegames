import type { Card, GameEngine, HistoryEntry, HolOutcome, Phase, Reveal } from "../lib/types";
import { BASE_MULTIPLIER, TOTAL_LOSS_MULTIPLIER } from "../lib/types";
import { CARD_MAX_VALUE, CARD_MIN_VALUE, RANK_COUNT, randomCard } from "../lib/cards";
import { gain, loss } from "../lib/format";
import type { Session } from "./session.svelte";
import { playCardDeal, playLoss, playRoundStart, playWin } from "../lib/audio";

const SEQUENCE_LIMIT = 9;
const HISTORY_LIMIT = 4;

export class HolEngine implements GameEngine {
  private readonly session: Session;

  phase = $state<Phase>("idle");
  card = $state<Card | null>(null);
  streak = $state(0);
  multiplier = $state(BASE_MULTIPLIER);
  won = $state(false);
  revealing = $state(false);
  sequence = $state<Card[]>([]);
  history = $state<HistoryEntry[]>([]);

  private fairMultiplier = 1;

  constructor(session: Session) {
    this.session = session;
  }

  get busy() {
    return this.phase === "live";
  }
  get cashValue() {
    return this.session.bet * this.multiplier;
  }
  get higherCount() {
    return this.card ? CARD_MAX_VALUE - this.card.value : 0;
  }
  get lowerCount() {
    return this.card ? this.card.value - CARD_MIN_VALUE : 0;
  }

  async primary() {
    if (this.revealing) return;
    if (this.phase === "resolved") return this.reset();
    if (this.phase === "live") return this.cashOut();
    await this.start();
  }

  async start() {
    const outcome = await this.session.placeBet<HolOutcome>(() => ({ card: randomCard() }));

    if (!outcome) return;

    this.dealCard(outcome.card);
  }

  dealCard(card: Card) {
    this.phase = "live";
    this.card = card;
    this.streak = 0;
    this.fairMultiplier = 1;
    this.multiplier = this.session.config.houseEdge;
    this.won = false;
    this.sequence = [card];
    playRoundStart();
  }

  async guess(higher: boolean) {
    if (this.phase !== "live" || this.revealing) return;

    this.revealing = true;
    const reveal = await this.session.reveal(higher, () => this.previewReveal(higher));
    this.revealing = false;

    if (!reveal || this.phase !== "live") return;

    this.applyReveal(reveal);
  }

  applyReveal(reveal: Reveal) {
    this.card = reveal.card;
    this.sequence = [...this.sequence, reveal.card].slice(-SEQUENCE_LIMIT);
    this.multiplier = reveal.multiplier;
    playCardDeal();

    if (reveal.correct) {
      this.streak = reveal.streak;
      if (reveal.exhausted) this.cashOut();
      return;
    }

    this.phase = "resolved";
    this.won = false;
    playLoss();
    this.record("Bust " + this.streak, loss(this.session.bet));
    void this.session.settle(TOTAL_LOSS_MULTIPLIER);
  }

  cashOut() {
    if (this.phase !== "live" || this.streak === 0) return;
    const multiplier = this.multiplier;
    this.cashOutAt(multiplier);
    void this.session.settle(multiplier);
  }

  cashOutAt(multiplier: number) {
    if (this.phase !== "live") return;
    this.multiplier = multiplier;
    this.phase = "resolved";
    this.won = true;
    playWin();
    this.record("Cashed " + this.streak, gain(this.session.bet * multiplier));
  }

  private record(label: string, value?: string) {
    this.history = [{ label, value }, ...this.history].slice(0, HISTORY_LIMIT);
  }

  private previewReveal(higher: boolean): Reveal {
    const current = this.card as Card;
    const card = randomCard();
    const correct = higher ? card.value > current.value : card.value < current.value;
    const streak = correct ? this.streak + 1 : this.streak;

    if (correct) {
      const winCount = higher ? CARD_MAX_VALUE - current.value : current.value - CARD_MIN_VALUE;
      this.fairMultiplier *= RANK_COUNT / winCount;
    }

    return {
      card,
      correct,
      streak,
      multiplier: correct
        ? this.session.config.houseEdge * this.fairMultiplier
        : TOTAL_LOSS_MULTIPLIER,
      exhausted: false
    };
  }

  reset() {
    this.phase = "idle";
    this.card = null;
    this.streak = 0;
    this.fairMultiplier = 1;
    this.multiplier = this.session.config.houseEdge;
    this.won = false;
    this.revealing = false;
    this.sequence = [];
  }

  cleanup() {}
}