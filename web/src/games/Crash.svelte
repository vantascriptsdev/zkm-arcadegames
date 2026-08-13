<script lang="ts">
  import type { Arcade } from "../state/arcade.svelte";
  import { gain, loss, money, multiplier } from "../lib/format";
  import GameTitle from "../components/GameTitle.svelte";
  import BalanceReadout from "../components/BalanceReadout.svelte";
  import BetControl from "../components/BetControl.svelte";
  import BetReadout from "../components/BetReadout.svelte";
  import HistoryTicks from "../components/HistoryTicks.svelte";
  import RailActions from "../components/RailActions.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";
  import Sparkline from "../components/Sparkline.svelte";

  interface Props {
    arcade: Arcade;
  }

  let { arcade }: Props = $props();

  let session = $derived(arcade.session);
  let engine = $derived(arcade.crash);

  const BAND_MID_THRESHOLD = 2;
  const BAND_HIGH_THRESHOLD = 5;

  let multiplierText = $derived(multiplier(engine.multiplier));
  let potentialText = $derived(money(session.bet * engine.multiplier));
  let resultLabel = $derived(engine.cashed ? "Cashed out" : "Crashed at");
  let resultValue = $derived(
    engine.cashed ? gain(session.bet * engine.multiplier) : loss(session.bet)
  );
  let bandMid = $derived(
    engine.multiplier >= BAND_MID_THRESHOLD && engine.multiplier < BAND_HIGH_THRESHOLD
  );
  let bandHigh = $derived(engine.multiplier >= BAND_HIGH_THRESHOLD);
  let primaryLabel = $derived(
    engine.phase === "live"
      ? "Cash out " + potentialText
      : engine.phase === "resolved"
        ? "Play again"
        : session.canAfford
          ? "Place bet"
          : "Not enough cash"
  );

  const legend = [
    { key: "E", action: "Play / Cash out" },
    { key: "↑ ↓", action: "Bet" },
    { key: "← →", action: "Min / Max" },
    { key: "ESC", action: "Quit Game" }
  ];
</script>

<div class="screen theme-crash">
  <div class="screen-grid">
    <GameTitle game={session.game} />
    <BalanceReadout balance={session.balance} hidden={!session.showBalance} />

    <div class="hero" class:band-mid={bandMid} class:band-high={bandHigh}>
      {#if engine.phase === "idle"}
        <div class="idle">
          <h1>Crash</h1>
          <div class="facts">
            <div>
              <div class="label">Bet range</div>
              <div class="num fact">
                {money(session.betMin)} &nbsp;—&nbsp; {money(session.betMax)}
              </div>
            </div>
          </div>
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
              <div class="cta-hint">Cash out before it crashes</div>
            </div>
          {/if}
        </div>
      {:else if engine.phase === "live"}
        <div>
          <div class="state-label live">Live</div>
          <div class="hero-num multiplier">{multiplierText}</div>
          <div class="inline-stats">
            <div>
              Potential &nbsp;<span class="num inline-value">{potentialText}</span>
            </div>
          </div>
          <Sparkline points={engine.trace} mode="live" />
        </div>
      {:else}
        <div class="resolve-in" class:cashed={engine.cashed}>
          <div class="state-label">{resultLabel}</div>
          <div class="hero-num result" data-result={resultValue}>{resultValue}</div>
          <div class="inline-stats">
            <div>
              At &nbsp;<span class="num inline-value locked">{multiplierText}</span>
            </div>
            <div>Bet &nbsp;<span class="num inline-value">{money(session.bet)}</span></div>
          </div>
          <Sparkline points={engine.trace} mode={engine.cashed ? "cashed" : "crashed"} />
        </div>
      {/if}
    </div>

    <div class="rail">
      {#if session.spectating}
        <BetReadout bet={session.bet} />
      {:else}
        <BetControl
          {session}
          disabled={arcade.locked}
          onstep={(direction) => arcade.stepBet(direction)}
          onset={(value) => arcade.setBet(value)}
          ondrag={(value) => arcade.dragBet(value)}
        />
      {/if}

      {#if session.showHistory}
        <HistoryTicks title="Last rounds" entries={engine.history} />
      {/if}

      {#if !session.spectating}
        <RailActions
          {primaryLabel}
          primaryDisabled={arcade.primaryBlocked}
          onprimary={() => arcade.primary()}
          onback={() => arcade.back()}
        />
      {/if}
    </div>

    {#if !session.spectating}
      <KeyLegend keys={legend} />
    {/if}
  </div>
</div>

<style>
  .screen-grid {
    grid-template-columns: 1fr var(--rail-width);
    grid-template-rows: auto 1fr auto;
    column-gap: var(--sp-96);
    row-gap: var(--sp-34);
  }

  .hero {
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    min-width: 0;
  }

  .hero.band-mid {
    --curve-ink: var(--climb-warm);
    --curve-glow: var(--climb-warm-glow);
  }

  .hero.band-high {
    --curve-ink: var(--climb-hot);
    --curve-glow: var(--climb-hot-glow);
  }

  .idle {
    display: flex;
    flex-direction: column;
    gap: var(--sp-26);
  }

  h1 {
    margin: 0;
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: var(--fs-hero-title);
    line-height: 0.84;
    letter-spacing: var(--ls-display-tight);
    color: var(--hero-ink);
  }

  .facts {
    display: flex;
    align-items: baseline;
    gap: var(--sp-44);
  }

  .fact {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-stat-lg) * var(--fs-data-scale));
    margin-top: var(--sp-6);
  }

  .cta-row {
    display: flex;
    align-items: center;
    gap: var(--sp-14);
    margin-top: var(--sp-10);
  }

  .state-label.live {
    color: var(--curve-ink);
    opacity: 1;
  }

  .multiplier {
    font-size: var(--fs-hero-value);
    color: var(--curve-ink);
    margin-top: var(--sp-10);
  }

  .result {
    --lock-glow: var(--c-loss-glow);
    position: relative;
    font-size: var(--fs-hero-resolved);
    color: var(--c-loss);
    margin-top: var(--sp-10);
    transform-origin: left center;
    animation: result-lock var(--dur-crash-hold) var(--ease-out) forwards;
  }

  .result::after {
    content: attr(data-result);
    position: absolute;
    inset: 0;
    color: transparent;
    text-shadow: 0 0 2.4cqh var(--lock-glow);
    pointer-events: none;
    animation: result-glow var(--dur-crash-hold) var(--ease-out) forwards;
  }

  .cashed .result {
    --lock-glow: var(--c-win-glow);
    color: var(--c-win);
  }

  @keyframes result-lock {
    0% {
      transform: scale(1.04);
    }
    8%,
    100% {
      transform: scale(1);
    }
  }

  @keyframes result-glow {
    0%,
    86% {
      opacity: 1;
    }
    100% {
      opacity: 0;
    }
  }

  .inline-stats {
    align-items: baseline;
    margin-top: var(--sp-14);
  }

  .inline-value.locked {
    color: var(--c-loss);
  }

  .cashed .inline-value.locked {
    color: var(--c-win);
  }

  .rail {
    gap: var(--sp-34);
  }
</style>
