<script lang="ts">
  import type { Arcade } from "../state/arcade.svelte";
  import { gain, loss, money, multiplier } from "../lib/format";
  import { RANK_COUNT, rankOf, suitOf } from "../lib/cards";
  import GameTitle from "../components/GameTitle.svelte";
  import BalanceReadout from "../components/BalanceReadout.svelte";
  import BetControl from "../components/BetControl.svelte";
  import BetReadout from "../components/BetReadout.svelte";
  import HistoryTicks from "../components/HistoryTicks.svelte";
  import RailActions from "../components/RailActions.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";
  import StatBlock from "../components/StatBlock.svelte";
  import PlayingCard from "../components/PlayingCard.svelte";

  interface Props {
    arcade: Arcade;
  }

  let { arcade }: Props = $props();

  let session = $derived(arcade.session);
  let engine = $derived(arcade.hol);

  let multiplierText = $derived(multiplier(engine.multiplier));
  let cashText = $derived(money(engine.cashValue));
  let streakText = $derived(
    engine.streak + (engine.phase === "live" ? " · " + multiplierText : ""),
  );
  let higherCount = $derived(engine.higherCount);
  let lowerCount = $derived(engine.lowerCount);
  let higherOdds = $derived(higherCount + "/" + RANK_COUNT);
  let lowerOdds = $derived(lowerCount + "/" + RANK_COUNT);
  let heroLabel = $derived(
    engine.phase === "resolved"
      ? engine.won
        ? "Final card"
        : "Revealed card"
      : "Current card",
  );
  let resultLabel = $derived(engine.won ? "Cashed out" : "Wrong guess");
  let resultValue = $derived(
    engine.won ? gain(engine.cashValue) : loss(session.bet),
  );
  let primaryLabel = $derived(
    engine.phase === "resolved"
      ? "Play again"
      : engine.phase === "live"
        ? engine.streak
          ? "Cash out " + cashText
          : "Cash out"
        : session.canAfford
          ? "Deal card"
          : "Not enough cash",
  );

  const legend = [
    { key: "E", action: "Play / Cash out" },
    { key: "W", action: "Higher" },
    { key: "S", action: "Lower" },
    { key: "↑ ↓", action: "Bet" },
    { key: "ESC", action: "Quit Game" },
  ];
</script>

<div class="screen theme-hol">
  <div class="screen-grid">
    <div class="topbar">
      <GameTitle game={session.game} />
      <BalanceReadout balance={session.balance} hidden={!session.showBalance} />
    </div>

    <div class="stage">
      <div class="hero">
        <div class="hero-head">
          {#if engine.phase !== "idle"}
            <div class="label">{heroLabel}</div>
          {/if}
          {#if engine.phase === "live"}
            <div class="streak">
              <div class="streak-key">Streak</div>
              <div class="num streak-value">{streakText}</div>
            </div>
          {/if}
        </div>

        {#if engine.phase === "idle"}
          <div class="idle">
            <h1>Higher<br />or Lower</h1>
            {#if !session.spectating}
              <div class="cta-row">
                <button
                  type="button"
                  class="cta"
                  disabled={arcade.primaryBlocked}
                  onclick={() => arcade.primary()}
                >
                  {session.canAfford ? "Press E to play" : "Not enough cash"}
                </button>
                <div class="cta-hint">Ties lose</div>
              </div>
            {/if}
          </div>
        {:else if engine.card}
          <PlayingCard card={engine.card} />
        {/if}
      </div>

      <div class="middle">
        {#if engine.phase === "live"}
          {#if !session.spectating}
            <div>
              <div class="label">Next card will be</div>
              <div class="guesses">
                <button
                  type="button"
                  class="guess primary"
                  disabled={engine.revealing || higherCount === 0}
                  onclick={() => void engine.guess(true)}
                >
                  <div class="guess-word">Higher</div>
                  <div class="guess-odds">
                    {higherOdds}{#if higherCount > 0}&nbsp;·&nbsp; key W{/if}
                  </div>
                </button>
                <button
                  type="button"
                  class="guess"
                  disabled={engine.revealing || lowerCount === 0}
                  onclick={() => void engine.guess(false)}
                >
                  <div class="guess-word">Lower</div>
                  <div class="guess-odds">
                    {lowerOdds}{#if lowerCount > 0}&nbsp;·&nbsp; key S{/if}
                  </div>
                </button>
              </div>
            </div>
          {/if}
          <div class="pair">
            <StatBlock label="Multiplier" value={multiplierText} accent />
            <StatBlock label="Cash out value" value={cashText} align="right" />
          </div>
        {:else if engine.phase === "resolved"}
          <div class="resolve-in">
            <div class="state-label">{resultLabel}</div>
            <div class="hero-num result">{resultValue}</div>
            <div class="inline-stats">
              <div>
                Streak &nbsp;<span class="num inline-value">{streakText}</span>
              </div>
              <div>
                Bet &nbsp;<span class="num inline-value"
                  >{money(session.bet)}</span
                >
              </div>
            </div>
          </div>
        {:else}
          <StatBlock
            label="Bet range"
            value="{money(session.betMin)} — {money(session.betMax)}"
            size="sm"
          />
        {/if}

        {#if session.showHistory && engine.sequence.length > 0}
          <div>
            <div class="label seq-label">Sequence</div>
            <div class="sequence">
              {#each engine.sequence as card, index (index)}
                <div class="seq-chip">{rankOf(card)}{suitOf(card).glyph}</div>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <div class="rail">
        {#if session.spectating}
          <BetReadout bet={session.bet} />
        {:else}
          <BetControl
            {session}
            showBounds={false}
            disabled={arcade.locked}
            onstep={(direction) => arcade.stepBet(direction)}
            onset={(value) => arcade.setBet(value)}
            ondrag={(value) => arcade.dragBet(value)}
          />
        {/if}

        <HistoryTicks
          title="Last rounds"
          entries={engine.history}
          layout="rows"
        />

        {#if !session.spectating}
          <RailActions
            {primaryLabel}
            primaryDisabled={arcade.primaryBlocked}
            onprimary={() => arcade.primary()}
            onback={() => arcade.back()}
          />
        {/if}
      </div>
    </div>

    <div class="footer">
      {#if !session.spectating}
        <KeyLegend keys={legend} />
      {/if}
    </div>
  </div>
</div>

<style>
  .screen-grid {
    grid-template-rows: auto 1fr auto;
    row-gap: var(--sp-30);
  }

  .topbar,
  .footer {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  }

  .stage {
    display: grid;
    grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr) var(
        --rail-width-narrow
      );
    column-gap: var(--sp-72);
    align-items: end;
    min-height: 0;
  }

  .hero {
    display: flex;
    flex-direction: column;
    gap: var(--sp-20);
    min-width: 0;
  }

  .hero-head {
    display: flex;
    align-items: baseline;
    gap: var(--sp-22);
    min-height: 1em;
  }

  .streak {
    display: flex;
    align-items: baseline;
    gap: var(--sp-10);
    background: var(--accent-tint);
    padding: var(--sp-6) var(--sp-12);
  }

  .streak-key {
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    color: var(--accent);
    opacity: 0.8;
  }

  .streak-value {
    font-weight: var(--fw-medium);
    font-size: calc(1.57cqh * var(--fs-data-scale));
    color: var(--accent);
  }

  .idle {
    display: flex;
    flex-direction: column;
    gap: var(--sp-22);
  }

  h1 {
    margin: 0;
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: var(--fs-hero-hol);
    line-height: var(--lh-title);
    letter-spacing: var(--ls-display-tight);
    color: var(--hero-ink);
  }

  .cta-row {
    display: flex;
    align-items: center;
    gap: var(--sp-14);
  }

  .cta-hint {
    font-size: var(--fs-label);
    opacity: var(--o-balance);
  }

  .middle {
    display: flex;
    flex-direction: column;
    gap: var(--sp-26);
    min-width: 0;
  }

  .guesses {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    margin-top: var(--sp-16);
  }

  .guess {
    appearance: none;
    border: var(--sp-2) solid transparent;
    background: var(--surface-4);
    color: var(--ink);
    padding: var(--sp-18) var(--sp-20);
    display: flex;
    flex-direction: column;
    gap: var(--sp-8);
    text-align: left;
    cursor: pointer;
    font: inherit;
    transition:
      background var(--dur-fast) linear,
      border-color var(--dur-fast) linear,
      opacity var(--dur-fast) linear;
  }

  .guess.primary:not(:disabled),
  .guess:hover:not(:disabled) {
    border-color: var(--accent);
    background: var(--accent-tint);
  }

  .guess:disabled {
    opacity: var(--o-hint);
    cursor: default;
    pointer-events: none;
  }

  .guess-word {
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: calc(var(--fs-guess) * 0.88);
    line-height: 1;
    opacity: 0.85;
  }

  .guess.primary:not(:disabled) .guess-word,
  .guess:hover:not(:disabled) .guess-word {
    opacity: 1;
  }

  .guess-odds {
    font-family: var(--font-ui);
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    font-variant-numeric: tabular-nums;
    opacity: var(--o-muted);
  }

  .result {
    font-size: var(--fs-hero-hol-resolved);
    line-height: var(--lh-hero-loose);
    color: var(--resolved-ink);
    margin-top: var(--sp-10);
  }

  .seq-label {
    opacity: var(--o-body);
  }

  .sequence {
    display: flex;
    gap: 1px;
    margin-top: var(--sp-12);
    flex-wrap: wrap;
  }

  .seq-chip {
    background: var(--surface-2);
    padding: 0.65cqh 1.02cqh;
    font-family: var(--font-mono);
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-chip) * var(--fs-data-scale));
    font-variant-numeric: tabular-nums;
    letter-spacing: var(--ls-data);
    opacity: 0.6;
  }

  .rail {
    gap: var(--sp-28);
    padding-left: var(--sp-26);
  }
</style>