<script lang="ts">
  import type { Arcade } from "../state/arcade.svelte";
  import { gain, largeMultiplier, loss, money } from "../lib/format";
  import GameTitle from "../components/GameTitle.svelte";
  import BalanceReadout from "../components/BalanceReadout.svelte";
  import BetControl from "../components/BetControl.svelte";
  import BetReadout from "../components/BetReadout.svelte";
  import HistoryTicks from "../components/HistoryTicks.svelte";
  import RailActions from "../components/RailActions.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";
  import StatBlock from "../components/StatBlock.svelte";

  interface Props {
    arcade: Arcade;
  }

  let { arcade }: Props = $props();

  let session = $derived(arcade.session);
  let engine = $derived(arcade.mines);

  const GEM_ICON = "./img/diamond.png";
  const BOMB_ICON = "./img/bomb.png";
  const FIRST_PICK = 1;

  let tiles = $derived(engine.tiles);
  let columns = $derived(Math.ceil(Math.sqrt(tiles)));

  let currentText = $derived(largeMultiplier(engine.multiplier));
  let nextMultText = $derived(largeMultiplier(engine.nextMultiplier));
  let nextValueText = $derived(money(session.bet * engine.nextMultiplier));
  let cashText = $derived(money(engine.cashValue));
  let gemsText = $derived(engine.gemCount + " / " + engine.remaining);

  let firstPickText = $derived(
    largeMultiplier(engine.multiplierAt(FIRST_PICK)),
  );
  let allClearText = $derived(
    largeMultiplier(engine.multiplierAt(engine.safeTiles)),
  );

  let resultLabel = $derived(engine.won ? "Cashed out" : "Hit a bomb");
  let resultValue = $derived(
    engine.won ? gain(engine.cashValue) : loss(session.bet),
  );

  let primaryLabel = $derived(
    engine.phase === "resolved"
      ? "Play again"
      : engine.phase === "live"
        ? engine.gemCount > 0
          ? "Cash out " + cashText
          : "Cash out"
        : session.canAfford
          ? "Place bet"
          : "Not enough cash",
  );

  let primaryDisabled = $derived(
    engine.phase === "live" ? !engine.canCashOut : arcade.primaryBlocked,
  );

  let board = $derived(
    Array.from({ length: tiles }, (_unused, index) => {
      const gem = engine.gems.includes(index);
      const bomb = engine.bombTiles.includes(index);

      return {
        index,
        gem,
        hit: engine.hitTile === index,
        bomb: bomb && engine.hitTile !== index,
        spent: engine.revealed && !gem && !bomb,
        down: !gem && !engine.revealed,
      };
    }),
  );

  let ticksEl: HTMLDivElement;
  let draggingBombs = $state(false);
  let hoverBombs = $state<number | null>(null);

  let maxBombs = $derived(session.config.minesMaxBombs);
  let bombsLocked = $derived(session.spectating || arcade.locked);

  let previewBombs = $derived(bombsLocked ? null : hoverBombs);

  let bombTicks = $derived(
    Array.from({ length: maxBombs }, (_unused, index) => {
      const count = index + 1;

      return {
        count,
        on: count <= engine.activeBombs,
        target: count === previewBombs,
        adding:
          previewBombs !== null &&
          count > engine.activeBombs &&
          count < previewBombs,
        cutting:
          previewBombs !== null &&
          count > previewBombs &&
          count <= engine.activeBombs,
      };
    }),
  );

  function bombsAt(clientX: number): number {
    const bounds = ticksEl.getBoundingClientRect();
    const fraction =
      bounds.width === 0 ? 0 : (clientX - bounds.left) / bounds.width;
    const count = Math.floor(fraction * maxBombs) + 1;

    return Math.min(maxBombs, Math.max(session.config.minesMinBombs, count));
  }

  function grabBombs(event: PointerEvent) {
    if (bombsLocked) return;
    draggingBombs = true;
    ticksEl.setPointerCapture(event.pointerId);
    hoverBombs = bombsAt(event.clientX);
    arcade.setBombs(hoverBombs);
  }

  function scrubBombs(event: PointerEvent) {
    if (bombsLocked) return;
    hoverBombs = bombsAt(event.clientX);
    if (draggingBombs) arcade.setBombs(hoverBombs);
  }

  function releaseBombs() {
    draggingBombs = false;
  }

  function leaveBombs() {
    if (draggingBombs) return;
    hoverBombs = null;
  }

  let pickable = $derived(
    !session.spectating && engine.phase === "live" && !engine.picking,
  );

  const legend = [
    { key: "E", action: "Play / Cash out" },
    { key: "Click", action: "Reveal tile" },
    { key: "↑ ↓", action: "Bet" },
    { key: "← →", action: "Bombs" },
    { key: "ESC", action: "Quit Game" },
  ];
</script>

<div class="screen theme-mines">
  <div class="screen-grid">
    <div class="nav"><GameTitle game={session.game} /></div>
    <BalanceReadout balance={session.balance} hidden={!session.showBalance} />

    <div class="hero">
      <div class="board" style:--mines-columns={columns}>
        {#each board as tile (tile.index)}
          {#if tile.down}
            <button
              type="button"
              class="tile down"
              disabled={!pickable}
              aria-label="Reveal tile {tile.index + 1}"
              onclick={() => void engine.pick(tile.index)}
            ></button>
          {:else if tile.gem}
            <div class="tile gem">
              <img class="pip" src={GEM_ICON} alt="Gem" />
            </div>
          {:else if tile.hit}
            <div class="tile bomb-hit">
              <img class="pip" src={BOMB_ICON} alt="Bomb" />
            </div>
          {:else if tile.bomb}
            <div class="tile bomb">
              <img class="pip" src={BOMB_ICON} alt="Bomb" />
            </div>
          {:else}
            <div class="tile spent"></div>
          {/if}
        {/each}
      </div>

      <div class="bombs" class:dimmed={engine.phase === "live"}>
        <div class="bombs-head">
          <div class="label">Bombs</div>
          <div class="bombs-count">
            <div class="num count">{engine.activeBombs}</div>
            <div class="of-tiles">of {tiles} tiles</div>
          </div>
        </div>
        <div
          bind:this={ticksEl}
          class="ticks"
          class:dragging={draggingBombs}
          role="group"
          aria-label="Bomb count"
          onpointerdown={grabBombs}
          onpointermove={scrubBombs}
          onpointerup={releaseBombs}
          onpointercancel={releaseBombs}
          onpointerleave={leaveBombs}
        >
          {#each bombTicks as tick (tick.count)}
            <button
              type="button"
              class="tick"
              class:on={tick.on}
              class:target={tick.target}
              class:adding={tick.adding}
              class:cutting={tick.cutting}
              disabled={bombsLocked}
              aria-label="{tick.count} bombs"
              onclick={() => arcade.setBombs(tick.count)}
            ></button>
          {/each}
        </div>
      </div>
    </div>

    <div class="readout">
      {#if engine.phase === "idle"}
        <div class="idle">
          <h1>Mines</h1>
          <div class="pair">
            <StatBlock label="First pick pays" value={firstPickText} accent />
            <StatBlock
              label="All {tiles} clear"
              value={allClearText}
              align="right"
            />
          </div>
          {#if !session.spectating}
            <div class="cta-col">
              <button
                type="button"
                class="cta"
                disabled={arcade.primaryBlocked}
                onclick={() => arcade.primary()}
              >
                {session.canAfford ? "Press E to play" : "Not enough cash"}
              </button>
              <div class="cta-hint">Cash out any time after one gem</div>
            </div>
          {/if}
        </div>
      {:else if engine.phase === "live"}
        <div class="live">
          <div>
            <div class="state-label accent-label">Next pick pays</div>
            <div class="hero-num next">{nextMultText}</div>
            <div class="num next-value">
              {nextValueText} &nbsp;<span class="qualifier">if safe</span>
            </div>
          </div>
          <div class="pair">
            <StatBlock label="Current" value={currentText} />
            <StatBlock label="Gems / left" value={gemsText} align="right" />
          </div>
        </div>
      {:else}
        <div class="resolve-in" class:won={engine.won}>
          <div class="state-label result-label">{resultLabel}</div>
          <div class="hero-num result">{resultValue}</div>
          <div class="inline-stats">
            <div>
              At &nbsp;<span class="num inline-value">{currentText}</span>
            </div>
            <div>
              Gems &nbsp;<span class="num inline-value">{engine.gemCount}</span>
            </div>
            <div>
              Bombs &nbsp;<span class="num inline-value"
                >{engine.activeBombs}</span
              >
            </div>
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
          disabled={arcade.locked}
          onstep={(direction) => arcade.stepBet(direction)}
          onset={(value) => arcade.setBet(value)}
          ondrag={(value) => arcade.dragBet(value)}
        />
      {/if}

      {#if session.showHistory}
        <HistoryTicks
          title="Last rounds"
          entries={engine.history}
          layout="rows"
        />
      {/if}

      {#if !session.spectating}
        <RailActions
          {primaryLabel}
          {primaryDisabled}
          onprimary={() => arcade.primary()}
          onback={() => arcade.back()}
        />
      {/if}
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
    grid-template-columns:
      minmax(0, 1.5fr)
      minmax(0, 0.9fr)
      var(--rail-width-narrow);
    grid-template-rows: auto minmax(0, 1fr) auto;
    column-gap: var(--sp-32);
    row-gap: var(--sp-18);
    padding: var(--sp-34) var(--sp-48) var(--sp-28);
    overflow: hidden;
  }

  .nav,
  .footer {
    grid-column: 1 / 3;
  }

  .hero {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: flex-start;
    gap: var(--sp-18);
    min-height: 0;
    min-width: 0;
    overflow: hidden;
  }

  .board {
    display: grid;
    grid-template-columns: repeat(var(--mines-columns), 1fr);
    gap: var(--tile-gap);
    width: min(100%, 66cqh);
    aspect-ratio: 1;
    flex: 0 0 auto;
  }

  .tile {
    appearance: none;
    border: 0;
    padding: 0;
    border-radius: var(--tile-radius);
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
    font-family: var(--font-ui);
  }

  .tile.down {
    background: var(--tile-face);
    cursor: pointer;
    transition:
      background var(--dur-instant) linear,
      transform var(--dur-instant) var(--ease-out);
  }

  .tile.down:hover:not(:disabled),
  .tile.down:focus-visible {
    background: var(--tile-face-hover);
    transform: translateY(-0.19cqh);
    outline: none;
  }

  .tile.down:disabled {
    cursor: default;
  }

  .tile.spent {
    background: var(--tile-spent);
    opacity: var(--o-balance);
  }

  @keyframes tileFaceIn {
    from {
      background: var(--tile-face);
    }
  }

  @keyframes pipIn {
    from {
      opacity: 0;
      transform: scale(0.7);
    }
  }

  .pip {
    display: block;
    width: var(--pip-size);
    aspect-ratio: 1;
    object-fit: contain;
    pointer-events: none;
    animation: pipIn var(--dur-resolve) var(--ease-out);
  }

  .tile.gem {
    --pip-size: var(--gem-size);
    background: var(--gem-tint);
    animation: tileFaceIn var(--dur-resolve) var(--ease-out);
  }

  .tile.gem .pip {
    animation-timing-function: var(--ease-pop);
  }

  .tile.bomb {
    --pip-size: var(--bomb-size);
    background: var(--bomb-tint);
    opacity: 0.55;
    animation: tileFaceIn var(--dur-resolve) var(--ease-out);
  }

  .tile.bomb-hit {
    --pip-size: var(--bomb-hit-size);
    background: var(--bomb-ink);
    box-shadow:
      0 0 0 var(--sp-2) var(--bomb-ring),
      0 0 4.07cqh var(--bomb-glow);
    animation: tileFaceIn var(--dur-resolve) var(--ease-out);
  }

  .bombs {
    width: min(100%, 66cqh);
    flex: 0 0 auto;
    transition: opacity var(--dur-fast) linear;
  }

  .bombs.dimmed {
    opacity: 0.32;
  }

  .bombs-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .bombs-count {
    display: flex;
    align-items: baseline;
    gap: var(--sp-18);
  }

  .count {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-bomb-count) * var(--fs-data-scale));
    line-height: 1;
    color: var(--accent);
  }

  .of-tiles {
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-balance);
  }

  .ticks {
    display: flex;
    gap: var(--sp-2);
    margin-top: var(--sp-12);
    height: var(--bomb-tick-height);
    touch-action: none;
  }

  .tick {
    appearance: none;
    border: 0;
    padding: 0;
    flex: 1;
    background: rgba(255, 255, 255, 0.08);
    cursor: pointer;
    transition:
      background var(--dur-instant) linear,
      opacity var(--dur-instant) linear;
  }

  .tick:hover:not(:disabled),
  .tick:focus-visible {
    background: rgba(255, 255, 255, 0.18);
    outline: none;
  }

  .tick.on {
    background: var(--accent);
  }

  .ticks .tick.target,
  .ticks .tick.adding {
    background: var(--accent);
  }

  .ticks .tick.adding {
    opacity: var(--o-muted);
  }

  .ticks .tick.cutting {
    opacity: var(--o-meta);
  }

  .ticks.dragging .tick {
    cursor: grabbing;
  }

  .tick:disabled {
    cursor: default;
  }

  .readout {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: var(--sp-24);
    min-width: 0;
    overflow: hidden;
  }

  .idle,
  .live {
    display: flex;
    flex-direction: column;
    gap: var(--sp-26);
  }

  .live {
    gap: var(--sp-24);
  }

  h1 {
    margin: 0;
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: var(--fs-hero-mines);
    line-height: var(--lh-hero-loose);
    letter-spacing: var(--ls-display-tight);
    color: var(--hero-ink);
  }

  .cta-col {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--sp-12);
  }

  .cta {
    flex: 0 0 auto;
    white-space: nowrap;
  }

  .cta-hint {
    text-wrap: pretty;
  }

  .accent-label {
    color: var(--accent);
    opacity: 1;
  }

  .next {
    font-size: var(--fs-hero-mines-value);
    color: var(--accent);
    margin-top: var(--sp-8);
  }

  .next-value {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-inline-stat) * var(--fs-data-scale));
    letter-spacing: var(--ls-data);
    opacity: var(--o-label);
    margin-top: var(--sp-10);
  }

  .qualifier {
    font-family: var(--font-ui);
    font-size: calc(var(--fs-inline-stat) * 0.92);
    letter-spacing: normal;
  }

  .result-label {
    color: var(--bomb-ink);
  }

  .won .result-label {
    color: var(--accent);
  }

  .result {
    font-size: var(--fs-hero-mines-resolved);
    line-height: var(--lh-hero-loose);
    color: var(--bomb-ink);
    margin-top: var(--sp-10);
  }

  .won .result {
    color: var(--accent);
  }

  .inline-stats {
    flex-wrap: wrap;
    gap: var(--sp-14) var(--sp-30);
  }

  .rail {
    gap: var(--sp-26);
    padding-left: var(--sp-26);
    min-height: 0;
    overflow: hidden;
  }
</style>