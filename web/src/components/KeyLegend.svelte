<script lang="ts">
  interface Props {
    keys: { key: string; action: string }[];
    layout?: "row" | "grid";
  }

  let { keys, layout = "row" }: Props = $props();
</script>

<div class="legend meta" class:grid={layout === "grid"}>
  {#each keys as entry (entry.key)}
    <div class="entry">
      <kbd class="key">{entry.key}</kbd>
      <span class="action">{entry.action}</span>
    </div>
  {/each}
</div>

<style>
  .legend {
    display: flex;
    gap: var(--sp-30);
    opacity: 1;
  }

  .legend.grid {
    display: grid;
    grid-template-columns: max-content auto;
    column-gap: var(--sp-14);
    row-gap: var(--sp-8);
    align-items: baseline;
  }

  .entry {
    display: flex;
    align-items: center;
    gap: var(--sp-8);
  }

  .legend.grid .entry {
    display: contents;
  }

  .key {
    font: inherit;
    text-transform: uppercase;
    letter-spacing: var(--ls-keycap);
    font-weight: var(--fw-semibold);
    line-height: 1;
    padding: var(--sp-6) var(--sp-8);
    background: var(--surface-6);
    box-shadow: inset 0 0 0 1px var(--divider);
    opacity: var(--o-nav-on);
  }

  .legend.grid .key {
    justify-self: end;
    text-align: center;
  }

  .action {
    opacity: var(--o-footer);
  }
</style>