<script lang="ts">
  import type { HistoryEntry } from "../lib/types";
  import { amountTone, multiplierTone } from "../lib/format";

  interface Props {
    title: string;
    entries: HistoryEntry[];
    layout?: "grid" | "rows";
  }

  let { title, entries, layout = "grid" }: Props = $props();

  let toned = $derived(
    entries.map((entry) => ({
      label: entry.label,
      value: entry.value,
      tone: entry.value === undefined ? multiplierTone(entry.label) : amountTone(entry.value)
    }))
  );
</script>

<div>
  <div class="label">{title}</div>
  <div class="ticks" class:rows={layout === "rows"}>
    {#if toned.length === 0}
      <div class="tick empty">No rounds yet</div>
    {/if}
    {#each toned as entry, index (index)}
      {#if layout === "rows"}
        <div class="tick row">
          <div class="key">{entry.label}</div>
          <div
            class="num value"
            class:win={entry.tone === "win"}
            class:loss={entry.tone === "loss"}
          >
            {entry.value}
          </div>
        </div>
      {:else}
        <div
          class="tick num"
          class:win={entry.tone === "win"}
          class:loss={entry.tone === "loss"}
        >
          {entry.label}
        </div>
      {/if}
    {/each}
  </div>
</div>

<style>
  .ticks {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1px;
    margin-top: var(--sp-14);
  }

  .ticks.rows {
    grid-template-columns: 1fr;
  }

  .tick {
    background: var(--surface-2);
    padding: 0.83cqh 0.93cqh;
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-tick) * var(--fs-data-scale));
    text-align: right;
    opacity: var(--o-tick);
  }

  .tick.empty {
    grid-column: 1 / -1;
    font-family: var(--font-ui);
    font-size: var(--fs-label);
    letter-spacing: normal;
    font-weight: var(--fw-regular);
    text-align: center;
    opacity: var(--o-hint);
  }

  .tick.row {
    display: flex;
    justify-content: space-between;
    padding: 0.83cqh 1.02cqh;
    font-family: var(--font-ui);
    font-size: var(--fs-label);
    letter-spacing: normal;
    font-weight: var(--fw-regular);
    text-align: left;
    opacity: 1;
  }

  .row .key {
    opacity: var(--o-tick);
  }

  .row .value {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-chip) * var(--fs-data-scale));
    opacity: var(--o-tick);
  }

  .row .value.win,
  .row .value.loss,
  .tick.win,
  .tick.loss {
    opacity: 0.92;
  }

  .win {
    color: var(--c-win);
  }

  .loss {
    color: var(--c-loss);
  }
</style>
