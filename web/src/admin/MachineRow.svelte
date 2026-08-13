<script lang="ts">
  import type { Machine } from "../lib/types";
  import { GAME_LABELS, isOccupied } from "../lib/types";
  import { coord, heading, since } from "../lib/format";

  interface Props {
    machine: Machine;
    index: number;
    confirming: boolean;
    blocked: boolean;
    busy: boolean;
    onteleport: () => void;
    onmove: () => void;
    onaskdelete: () => void;
    onconfirmdelete: () => void;
    ondismiss: () => void;
  }

  let {
    machine,
    index,
    confirming,
    blocked,
    busy,
    onteleport,
    onmove,
    onaskdelete,
    onconfirmdelete,
    ondismiss
  }: Props = $props();

  const POP_STAGGER_MS = 22;
  const POP_STAGGER_CAP_MS = 260;

  let occupied = $derived(isOccupied(machine));
  let stateText = $derived(occupied ? `In use · ${machine.occupiedBy}` : "Free");
  let popDelay = $derived(`${Math.min(index * POP_STAGGER_MS, POP_STAGGER_CAP_MS)}ms`);
</script>

<div
  class="row"
  class:occupied
  class:selected={confirming || blocked}
  style:--row-pop-delay={popDelay}
>
  <div class="cells">
    <div class="num id">{machine.id}</div>
    <div class="game">{GAME_LABELS[machine.game]}</div>
    <div class="coords">
      <div class="num">{coord(machine.x)}</div>
      <div class="num">{coord(machine.y)}</div>
      <div class="num">{coord(machine.z)}</div>
    </div>
    <div class="num heading">{heading(machine.heading)}</div>
    <div class="author">{machine.createdBy} · {since(machine.createdAt)}</div>
    <div class="state">{stateText}</div>
    <div class="actions">
      <button type="button" class="action" disabled={busy} onclick={onteleport}>
        Teleport
      </button>
      <button type="button" class="action" disabled={busy || occupied} onclick={onmove}>Move</button>
      <button
        type="button"
        class="action danger"
        disabled={occupied || busy}
        onclick={onaskdelete}
      >
        Delete
      </button>
    </div>
  </div>

  {#if confirming}
    <div class="prompt confirm resolve-in">
      <div class="prompt-text">
        Delete machine {machine.id}? This cannot be undone.
      </div>
      <div class="prompt-actions">
        <button type="button" class="destroy" disabled={busy} onclick={onconfirmdelete}>
          Delete
        </button>
        <button type="button" class="quiet" onclick={ondismiss}>Cancel</button>
      </div>
    </div>
  {/if}

  {#if blocked}
    <div class="prompt blocked resolve-in">
      <div class="prompt-text">
        Can't delete — {machine.occupiedBy} is playing this machine. Wait until it's free.
      </div>
      <div class="prompt-actions">
        <button type="button" class="quiet" onclick={ondismiss}>Dismiss</button>
      </div>
    </div>
  {/if}
</div>

<style>
  @keyframes rowPopIn {
    from {
      opacity: 0;
      transform: translateY(var(--sp-10)) scale(0.985);
    }
  }

  .row {
    border-top: 1px solid var(--divider);
    padding: var(--sp-18) var(--sp-14) var(--sp-18) var(--sp-14);
    animation: rowPopIn var(--dur-resolve) var(--ease-pop) var(--row-pop-delay) both;
  }

  .row.occupied {
    background: var(--surface-1);
    box-shadow: inset 2px 0 0 var(--surface-6);
  }

  .row.selected {
    background: var(--surface-4);
    box-shadow: inset 2px 0 0 var(--c-delete);
  }

  .cells {
    display: grid;
    grid-template-columns: var(--table-cols);
    align-items: center;
    gap: var(--sp-14);
  }

  .id {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-slot) * var(--fs-data-scale));
    letter-spacing: var(--ls-data);
    opacity: var(--o-nav-on);
  }

  .game,
  .author,
  .state {
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .game {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: 0.72;
  }

  .coords {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--sp-12);
    min-width: 0;
    text-align: right;
  }

  .coords .num,
  .heading {
    font-weight: var(--fw-regular);
    font-size: calc(var(--fs-tick) * var(--fs-data-scale));
    opacity: var(--o-body);
  }

  .heading {
    text-align: right;
  }

  .author {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
  }

  .state {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: 0.4;
  }

  .row.occupied .state {
    font-weight: var(--fw-semibold);
    opacity: 0.82;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--sp-12);
    white-space: nowrap;
  }

  .action {
    appearance: none;
    border: 0;
    background: none;
    padding: 0;
    color: var(--ink);
    font-family: var(--font-ui);
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: 0.62;
    cursor: pointer;
    transition:
      color var(--dur-fast) linear,
      opacity var(--dur-fast) linear;
  }

  .action:hover:not(:disabled) {
    color: var(--accent);
    opacity: 1;
  }

  .action:focus-visible {
    outline: 1px solid var(--accent);
    outline-offset: var(--sp-2);
  }

  .action.danger {
    color: var(--c-delete);
    opacity: 0.8;
  }

  .action.danger:hover:not(:disabled) {
    color: var(--c-delete);
    opacity: 1;
  }

  .action.danger:disabled {
    color: var(--c-delete);
    opacity: 0.28;
  }

  .action:disabled {
    cursor: default;
    opacity: var(--o-hint);
  }

  .prompt {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-24);
    margin-top: var(--sp-16);
    margin-right: var(--sp-14);
    padding: var(--sp-14) var(--sp-18);
  }

  .prompt.confirm {
    background: var(--c-delete-tint);
  }

  .prompt.blocked {
    background: var(--c-delete-tint);
    border-left: 2px solid var(--c-delete);
  }

  .prompt-text {
    font-size: var(--fs-chip);
    font-weight: var(--fw-regular);
    color: var(--c-delete);
  }

  .prompt.blocked .prompt-text {
    opacity: 0.85;
  }

  .prompt-actions {
    display: flex;
    align-items: center;
    gap: var(--sp-16);
    flex: 0 0 auto;
  }

  .destroy {
    appearance: none;
    border: 0;
    background: var(--c-delete);
    color: var(--c-delete-ink);
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: var(--fs-chip);
    padding: var(--sp-10) var(--sp-20);
    cursor: pointer;
    transition: opacity var(--dur-fast) linear;
  }

  .destroy:hover:not(:disabled) {
    opacity: 0.88;
  }

  .destroy:disabled {
    opacity: var(--o-hint);
    cursor: default;
  }

  .destroy:focus-visible,
  .quiet:focus-visible {
    outline: 1px solid var(--accent);
    outline-offset: var(--sp-2);
  }

  @container admin (max-width: 1180px) {
    .author {
      display: none;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .action,
    .destroy {
      transition: none;
    }

    .row,
    .prompt {
      animation: none;
    }
  }
</style>
