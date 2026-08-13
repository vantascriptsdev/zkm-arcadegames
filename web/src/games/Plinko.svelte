<script lang="ts">
  import type { Arcade } from "../state/arcade.svelte";
  import type { RiskLevel } from "../lib/types";
  import { RISK_LABELS } from "../lib/types";
  import { gain } from "../lib/format";
  import { ROWS, SLOT_COUNT, RISK_LEVELS } from "../state/plinko.svelte";
  import GameTitle from "../components/GameTitle.svelte";
  import BalanceReadout from "../components/BalanceReadout.svelte";
  import BetControl from "../components/BetControl.svelte";
  import BetReadout from "../components/BetReadout.svelte";
  import HistoryTicks from "../components/HistoryTicks.svelte";
  import RailActions from "../components/RailActions.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";

  interface Props {
    arcade: Arcade;
  }

  let { arcade }: Props = $props();

  let session = $derived(arcade.session);
  let engine = $derived(arcade.plinko);

  const FIRST_PEG_ROW_COUNT = 3;
  const TRAIL_LAYERS = [1, 2, 3];
  const NO_PEG = -1;
  const NO_SQUASH = -1;
  const BREAK_EVEN_MULTIPLIER = 1;
  const SLOT_CENTRE = 0.5;
  const HALF_DEFLECTION = 2;
  const BOARD_TRAVEL = 96;

  const pegRows = Array.from(
    { length: ROWS },
    (_unused, rowIndex) => rowIndex + FIRST_PEG_ROW_COUNT,
  );

  const HUE_WRAP = 360;
  const HUE_COOL = 250;
  const HUE_WARM = 384;
  const SATURATION_COOL = 20;
  const SATURATION_WARM = 88;
  const BACKDROP_LIGHTNESS_COOL = 11;
  const BACKDROP_LIGHTNESS_WARM = 33;
  const LABEL_LIGHTNESS_COOL = 66;
  const LABEL_LIGHTNESS_WARM = 97;
  const STRONG_HEAT = 0.55;
  const QUIETEST_MULTIPLIER = 0.01;
  const COOLEST = 0;
  const HOTTEST = 1;

  const mix = (from: number, to: number, amount: number): number =>
    from + (to - from) * amount;

  function payoutHeat(
    multiplier: number,
    lowest: number,
    highest: number,
  ): number {
    const floor = Math.log(Math.max(QUIETEST_MULTIPLIER, lowest));
    const ceiling = Math.log(Math.max(QUIETEST_MULTIPLIER, highest));

    if (ceiling <= floor) return COOLEST;

    const value = Math.log(Math.max(QUIETEST_MULTIPLIER, multiplier));
    const heat = (value - floor) / (ceiling - floor);

    return Math.min(HOTTEST, Math.max(COOLEST, heat));
  }

  function heatColor(heat: number, lightness: number): string {
    const hue = mix(HUE_COOL, HUE_WARM, heat) % HUE_WRAP;
    const saturation = mix(SATURATION_COOL, SATURATION_WARM, heat);

    return `hsl(${hue.toFixed(0)}, ${saturation.toFixed(0)}%, ${lightness.toFixed(0)}%)`;
  }

  let chips = $derived.by(() => {
    const payouts = engine.payouts;
    const hitSlot = engine.phase === "resolved" ? engine.slot : null;
    const lowest = Math.min(...payouts);
    const highest = Math.max(...payouts);

    return payouts.map((value, slotIndex) => {
      const heat = payoutHeat(value, lowest, highest);

      return {
        label: value + "x",
        hit: hitSlot === slotIndex,
        strong: heat >= STRONG_HEAT,
        backdrop: heatColor(
          heat,
          mix(BACKDROP_LIGHTNESS_COOL, BACKDROP_LIGHTNESS_WARM, heat),
        ),
        ink: heatColor(
          heat,
          mix(LABEL_LIGHTNESS_COOL, LABEL_LIGHTNESS_WARM, heat),
        ),
      };
    });
  });

  let landed = $derived(
    engine.slot === null ? null : engine.payouts[engine.slot],
  );
  let landedCentre = $derived(
    engine.slot === null ? 0 : (engine.slot + SLOT_CENTRE) / SLOT_COUNT,
  );
  let landedNegative = $derived(
    landed !== null && landed < BREAK_EVEN_MULTIPLIER,
  );
  let winText = $derived(landed === null ? "" : gain(session.bet * landed));
  let slotText = $derived(landed === null ? "" : landed + "x");
  let primaryLabel = $derived(
    engine.phase === "resolved"
      ? "Play again"
      : engine.phase === "live"
        ? "Dropping"
        : session.canAfford
          ? "Drop ball"
          : "Not enough cash",
  );

  let drift = $derived(
    engine.step > 0
      ? engine.path
          .slice(0, engine.step)
          .reduce((total, direction) => total + direction, 0)
      : 0,
  );
  let ballFraction = $derived(
    (ROWS / 2 + SLOT_CENTRE + drift / HALF_DEFLECTION) / SLOT_COUNT,
  );
  let ballProgress = $derived(
    engine.step <= 0 ? 0 : Math.min(1, engine.step / ROWS),
  );
  let ballShift = $derived(
    `translate(${ballFraction * 100}%, ${ballProgress * BOARD_TRAVEL}%)`,
  );
  let litRow = $derived(engine.phase === "live" ? engine.step : NO_PEG);
  let litPeg = $derived(
    litRow === NO_PEG
      ? NO_PEG
      : (litRow + FIRST_PEG_ROW_COUNT - 1 + drift) / HALF_DEFLECTION,
  );
  let squashPhase = $derived(
    engine.phase === "live" ? engine.step % 2 : NO_SQUASH,
  );

  const legend = [
    { key: "E", action: "Drop ball" },
    { key: "↑ ↓", action: "Bet" },
    { key: "1 2 3", action: "Risk" },
    { key: "ESC", action: "Quit Game" },
  ];
</script>

<div class="screen theme-plinko">
  <div class="screen-grid">
    <GameTitle game={session.game} />
    <BalanceReadout balance={session.balance} hidden={!session.showBalance} />

    <div class="hero">
      <div class="hero-head">
        <div class="hero-title">
          {#if engine.phase === "idle"}
            <h1>Plinko</h1>
          {:else if engine.phase === "live"}
            <div class="title-num" aria-hidden="true">&nbsp;</div>
          {:else}
            <div class="landed resolve-in">
              <div class="title-num">{winText}</div>
              <div class="landed-slot">Landed {slotText}</div>
            </div>
          {/if}
        </div>
        <div class="board-meta">
          {ROWS} rows &nbsp;·&nbsp; risk {RISK_LABELS[engine.risk]}
        </div>
      </div>

      <div class="board" style:--slot-count={SLOT_COUNT}>
        {#each pegRows as pegCount, rowIndex (rowIndex)}
          <div class="peg-row">
            {#each Array(pegCount) as _unused, pegIndex (pegIndex)}
              <div
                class="peg"
                class:lit={rowIndex === litRow && pegIndex === litPeg}
              ></div>
            {/each}
          </div>
        {/each}

        {#each TRAIL_LAYERS as layer (layer)}
          <div
            class="mover trail-mover"
            style:--trail-layer={layer}
            style:--ball-step="{engine.stepDurationMs}ms"
            style:transform={ballShift}
          >
            <div class="trail" class:released={engine.phase !== "idle"}></div>
          </div>
        {/each}

        <div
          class="mover"
          style:--ball-step="{engine.stepDurationMs}ms"
          style:transform={ballShift}
        >
          <div class="ball" class:released={engine.phase !== "idle"}>
            <div
              class="ball-core"
              class:squash-even={squashPhase === 0}
              class:squash-odd={squashPhase === 1}
            ></div>
          </div>
        </div>
      </div>

      <div class="strip">
        {#each chips as chip, chipIndex (chipIndex)}
          <div
            class="chip"
            class:strong={chip.strong}
            class:hit={chip.hit}
            style:--chip-backdrop={chip.backdrop}
            style:--chip-ink={chip.ink}
          >
            <span class="chip-label">{chip.label}</span>
          </div>
        {/each}

        {#if engine.phase === "resolved" && engine.slot !== null}
          <div
            class="payout"
            class:negative={landedNegative}
            style:left="{landedCentre * 100}%"
          >
            {winText}
          </div>
        {/if}
      </div>
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

        <div>
          <div class="label">Risk</div>
          <div class="risks">
            {#each RISK_LEVELS as level (level)}
              <button
                type="button"
                class:on={engine.risk === level}
                onclick={() => engine.setRisk(level as RiskLevel)}
              >
                {RISK_LABELS[level as RiskLevel]}
              </button>
            {/each}
          </div>
        </div>
      {/if}

      {#if session.showHistory}
        <HistoryTicks title="Recent drops" entries={engine.history} />
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
    row-gap: var(--sp-28);
  }

  .hero {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .hero-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .hero-title {
    display: flex;
    align-items: baseline;
    gap: var(--sp-26);
  }

  h1,
  .title-num {
    margin: 0;
    line-height: var(--lh-plinko);
  }

  h1 {
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: var(--fs-hero-plinko);
    letter-spacing: var(--ls-display-tight);
    color: var(--hero-ink);
  }

  .title-num {
    font-family: var(--font-mono);
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-hero-plinko) * var(--fs-data-scale));
    font-variant-numeric: tabular-nums;
    letter-spacing: var(--ls-data);
    color: var(--resolved-ink);
  }

  .landed {
    display: flex;
    align-items: baseline;
    gap: var(--sp-22);
  }

  .landed-slot {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
  }

  .board-meta {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-muted);
  }

  .board {
    position: relative;
    flex: 1;
    min-height: 0;
    margin-top: var(--sp-22);
    width: min(100%, var(--board-width));
    align-self: center;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: var(--sp-14) 0 var(--sp-6);
  }

  .peg-row {
    display: flex;
    justify-content: center;
    gap: calc(100% / var(--slot-count) - var(--peg-size));
  }

  .peg {
    width: var(--peg-size);
    height: var(--peg-size);
    border-radius: 50%;
    background: var(--peg);
  }

  .peg.lit {
    animation: peg-pulse var(--dur-peg-pulse) var(--ease-out);
  }

  @keyframes peg-pulse {
    0% {
      background: var(--peg-lit);
      transform: scale(1.8);
    }
    100% {
      background: var(--peg);
      transform: scale(1);
    }
  }

  .mover {
    position: absolute;
    inset: 0;
    pointer-events: none;
    transition: transform var(--ball-step, var(--dur-instant)) linear;
    will-change: transform;
  }

  .trail,
  .ball {
    position: absolute;
    top: 0;
    left: 0;
    transform: translate(-50%, -50%);
    opacity: 0;
    transition: opacity var(--dur-fast) linear;
  }

  .ball {
    width: var(--ball-size);
    height: var(--ball-size);
  }

  .ball.released {
    opacity: 1;
  }

  .ball-core {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    background: var(--ink);
    box-shadow:
      0 0 0 1px var(--accent-bright),
      0 0 1cqh var(--ball-glow),
      0 0 2.6cqh var(--ball-glow);
  }

  .ball-core.squash-even {
    animation: ball-squash-even var(--dur-peg-pulse) var(--ease-out);
  }

  .ball-core.squash-odd {
    animation: ball-squash-odd var(--dur-peg-pulse) var(--ease-out);
  }

  @keyframes ball-squash-even {
    0% {
      transform: scale(1, 1);
    }
    24% {
      transform: scale(1.22, 0.8);
    }
    100% {
      transform: scale(1, 1);
    }
  }

  @keyframes ball-squash-odd {
    0% {
      transform: scale(1, 1);
    }
    24% {
      transform: scale(1.22, 0.8);
    }
    100% {
      transform: scale(1, 1);
    }
  }

  .trail {
    width: calc(var(--ball-size) * (1 - var(--trail-layer) * 0.18));
    height: calc(var(--ball-size) * (1 - var(--trail-layer) * 0.18));
    border-radius: 50%;
    background: var(--accent-bright);
  }

  .trail-mover {
    transition-delay: calc(var(--trail-layer) * 55ms);
  }

  .trail.released {
    opacity: calc(0.4 / var(--trail-layer));
  }

  .strip {
    position: relative;
    display: flex;
    gap: 1px;
    margin-top: var(--sp-16);
    width: min(100%, var(--board-width));
    align-self: center;
  }

  .chip {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-align: center;
    padding: 1.02cqh 0;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
    letter-spacing: var(--ls-data);
    font-size: calc(var(--fs-tick) * var(--fs-data-scale));
    font-weight: var(--fw-regular);
    background: var(--chip-backdrop, var(--surface-3));
    color: var(--chip-ink, var(--ink));
  }

  .chip.strong {
    font-size: calc(var(--fs-slot) * var(--fs-data-scale));
    font-weight: var(--fw-medium);
  }

  .chip.hit {
    position: relative;
    background: var(--accent);
    color: var(--on-accent);
    font-weight: var(--fw-medium);
  }

  .chip-label {
    position: relative;
    z-index: 1;
  }

  .chip.hit::before {
    content: "";
    position: absolute;
    inset: 0;
    background: var(--ink);
    animation: bucket-flash var(--dur-bucket-flash) var(--ease-out) 3;
  }

  @keyframes bucket-flash {
    0% {
      opacity: 1;
    }
    100% {
      opacity: 0;
    }
  }

  .payout {
    position: absolute;
    bottom: 100%;
    margin-bottom: var(--sp-12);
    transform: translate(-50%, 0);
    pointer-events: none;
    z-index: 1;
    white-space: nowrap;
    font-family: var(--font-display);
    font-variant-numeric: tabular-nums;
    font-weight: var(--fw-display);
    font-size: var(--fs-stat-lg);
    letter-spacing: var(--ls-display-tight);
    color: var(--c-win);
    text-shadow: 0 0 1.2cqh var(--c-win-glow);
    animation: payout-float var(--dur-payout-float) var(--ease-out) forwards;
  }

  .payout.negative {
    color: var(--c-loss);
    text-shadow: 0 0 1.2cqh var(--c-loss-glow);
  }

  @keyframes payout-float {
    0% {
      opacity: 0;
      transform: translate(-50%, var(--sp-14));
    }
    16% {
      opacity: 1;
      transform: translate(-50%, 0);
    }
    70% {
      opacity: 1;
      transform: translate(-50%, 0);
    }
    100% {
      opacity: 0;
      transform: translate(-50%, calc(var(--sp-14) * -1));
    }
  }

  .rail {
    gap: var(--sp-32);
  }

  .risks {
    display: flex;
    gap: var(--sp-2);
    margin-top: var(--sp-14);
  }

  .risks button {
    appearance: none;
    border: 0;
    flex: 1;
    font: inherit;
    font-family: var(--font-ui);
    color: var(--ink);
    background: var(--surface-2);
    text-align: center;
    padding: 1.02cqh 0;
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-muted);
    cursor: pointer;
    transition:
      background var(--dur-fast) linear,
      opacity var(--dur-fast) linear;
  }

  .risks button:hover {
    opacity: 0.7;
  }

  .risks button.on {
    background: var(--accent-tint);
    color: var(--accent-bright);
    font-weight: var(--fw-semibold);
    opacity: 1;
  }
</style>