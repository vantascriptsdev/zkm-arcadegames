<script lang="ts">
  import type { Card } from "../lib/types";
  import { rankOf, suitOf } from "../lib/cards";

  interface Props {
    card: Card;
  }

  let { card }: Props = $props();

  let suit = $derived(suitOf(card));
</script>

{#key card}
  <div class="card" class:red={suit.red}>
    <div class="corner">
      <div class="rank">{rankOf(card)}</div>
      <div class="suit">{suit.glyph}</div>
    </div>
    <div class="pip">{suit.glyph}</div>
    <div class="corner flipped">
      <div class="rank">{rankOf(card)}</div>
      <div class="suit">{suit.glyph}</div>
    </div>
  </div>
{/key}

<style>
  .card {
    animation: resolveIn var(--dur-deal) var(--ease-out);
    width: min(100%, var(--card-width));
    aspect-ratio: 5 / 7;
    background: var(--card-face);
    border-radius: var(--card-radius);
    padding: var(--sp-22) var(--sp-24);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    color: var(--card-ink);
  }

  .card.red {
    color: var(--card-ink-red);
  }

  .corner {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .corner.flipped {
    transform: rotate(180deg);
  }

  .rank {
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: var(--fs-card-rank);
    line-height: 0.8;
    letter-spacing: -0.01em;
    color: var(--card-ink);
  }

  .suit {
    font-size: var(--fs-card-suit-sm);
    line-height: 1;
  }

  .pip {
    font-size: var(--fs-card-suit-lg);
    line-height: 0.8;
    text-align: center;
    opacity: 0.92;
  }
</style>