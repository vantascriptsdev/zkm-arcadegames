<script lang="ts">
  import { money } from "../lib/format";
  import type { Session } from "../state/session.svelte";

  interface Props {
    session: Session;
    showBounds?: boolean;
    disabled?: boolean;
    onstep: (direction: 1 | -1) => void;
    onset: (value: number) => void;
    ondrag: (value: number) => void;
  }

  let { session, showBounds = true, disabled = false, onstep, onset, ondrag }: Props = $props();

  let sliderEl: HTMLDivElement;
  let trackEl: HTMLDivElement;
  let dragging = $state(false);
  let trackBounds: DOMRect | null = null;

  function valueAt(clientX: number): number {
    const bounds = trackBounds ?? trackEl.getBoundingClientRect();
    const fraction = bounds.width === 0 ? 0 : (clientX - bounds.left) / bounds.width;
    return session.betMin + Math.min(1, Math.max(0, fraction)) * (session.betMax - session.betMin);
  }

  function grab(event: PointerEvent) {
    if (disabled) return;
    dragging = true;
    trackBounds = trackEl.getBoundingClientRect();
    sliderEl.setPointerCapture(event.pointerId);
    ondrag(valueAt(event.clientX));
  }

  function scrub(event: PointerEvent) {
    if (!dragging) return;
    ondrag(valueAt(event.clientX));
  }

  function release() {
    if (!dragging) return;
    dragging = false;
    trackBounds = null;
    onset(session.bet);
  }

  function handleKeyDown(event: KeyboardEvent) {
    if (disabled) return;
    if (event.key === "Home") {
      event.preventDefault();
      onset(session.betMin);
    } else if (event.key === "End") {
      event.preventDefault();
      onset(session.betMax);
    }
  }
</script>

<div>
  <div class="head">
    <div class="label">Bet</div>
    <div class="num amount">{money(session.bet)}</div>
  </div>

  <div
    bind:this={sliderEl}
    class="slider"
    class:tight={!showBounds}
    class:dragging
    class:disabled
    role="slider"
    tabindex={disabled ? -1 : 0}
    aria-label="Bet"
    aria-orientation="horizontal"
    aria-valuemin={session.betMin}
    aria-valuemax={session.betMax}
    aria-valuenow={session.bet}
    aria-valuetext={money(session.bet)}
    aria-disabled={disabled}
    onpointerdown={grab}
    onpointermove={scrub}
    onpointerup={release}
    onpointercancel={release}
    onkeydown={handleKeyDown}
  >
    <div class="track" bind:this={trackEl}>
      <div class="handle" style:left="{session.betFraction * 100}%"></div>
    </div>
  </div>

  {#if showBounds}
    <div class="bounds" class:disabled>
      <button type="button" {disabled} onclick={() => onset(session.betMin)}>
        Min {session.betMin.toLocaleString("en-US")}
      </button>
      <button type="button" {disabled} onclick={() => onset(session.betMax)}>
        Max {session.betMax.toLocaleString("en-US")}
      </button>
    </div>
  {/if}

  <div class="steppers" class:tight={!showBounds} class:disabled>
    <button type="button" {disabled} onclick={() => onstep(-1)}>−</button>
    <button type="button" {disabled} onclick={() => onstep(1)}>+</button>
  </div>
</div>

<style>
  .head {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  }

  .amount {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-bet) * var(--fs-data-scale));
  }

  .slider {
    --hit: var(--sp-10);
    padding: var(--hit) 0;
    cursor: pointer;
    touch-action: none;
  }

  .slider.tight {
    margin: calc(var(--sp-18) - var(--hit)) 0 calc(var(--sp-10) - var(--hit));
  }

  .slider.dragging {
    cursor: grabbing;
  }

  .slider.disabled,
  .bounds.disabled,
  .steppers.disabled {
    cursor: default;
    opacity: var(--o-muted);
    pointer-events: none;
  }

  .track {
    --handle-size: clamp(5px, 0.65cqh, 14px);
    position: relative;
    height: 1px;
    background: var(--track);
  }

  .handle {
    position: absolute;
    top: calc((1px - var(--handle-size)) / 2);
    width: var(--handle-size);
    height: var(--handle-size);
    background: var(--ink);
    transform: translateX(-50%);
    transition:
      left var(--dur-fast) linear,
      transform var(--dur-fast) linear,
      background var(--dur-fast) linear;
  }

  .slider:hover .handle {
    transform: translateX(-50%) scale(1.5);
  }

  .slider:focus-visible {
    outline: none;
  }

  .slider:focus-visible .handle {
    background: var(--accent);
    transform: translateX(-50%) scale(1.5);
  }

  .slider.dragging .handle {
    transform: translateX(-50%) scale(1.5);
    transition: transform var(--dur-fast) linear;
  }

  .slider.disabled .handle {
    transform: translateX(-50%);
  }

  .bounds {
    display: flex;
    justify-content: space-between;
  }

  .bounds button {
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-hint);
    background: none;
    padding: 0;
  }

  .bounds button:hover {
    opacity: var(--o-body);
  }

  .steppers {
    display: flex;
    gap: var(--sp-2);
    margin-top: var(--sp-16);
  }

  .steppers.tight {
    margin-top: var(--sp-14);
  }

  .steppers button {
    flex: 1;
    background: var(--surface-4);
    padding: var(--sp-10) 0;
    font-size: var(--fs-nav);
    font-weight: var(--fw-regular);
  }

  .steppers button:hover {
    background: var(--surface-6);
  }

  button {
    appearance: none;
    border: 0;
    font: inherit;
    font-family: var(--font-ui);
    color: var(--ink);
    text-align: center;
    cursor: pointer;
    transition:
      background var(--dur-fast) linear,
      opacity var(--dur-fast) linear;
  }
</style>