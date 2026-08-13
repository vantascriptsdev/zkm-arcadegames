<script lang="ts">
  import type { SortDirection } from "../lib/types";

  interface Props {
    label: string;
    active: boolean;
    direction: SortDirection;
    align?: "left" | "right";
    onsort: () => void;
  }

  let { label, active, direction, align = "left", onsort }: Props = $props();

  let arrow = $derived(active && direction === "desc" ? "↓" : "↑");
  let nextDirection = $derived(active && direction === "asc" ? "descending" : "ascending");
  let hint = $derived(
    active
      ? `${label}, sorted ${direction === "asc" ? "ascending" : "descending"}. Sort ${nextDirection}`
      : `Sort by ${label}`
  );
</script>

<button
  type="button"
  class="sort"
  class:right={align === "right"}
  class:on={active}
  aria-label={hint}
  onclick={onsort}
>
  <span>{label}</span>
  <span class="arrow" class:shown={active} aria-hidden="true">{arrow}</span>
</button>

<style>
  .sort {
    appearance: none;
    border: 0;
    background: none;
    display: flex;
    align-items: baseline;
    gap: var(--sp-6);
    padding: 0;
    width: 100%;
    color: var(--ink);
    font: inherit;
    letter-spacing: inherit;
    text-transform: inherit;
    white-space: nowrap;
    cursor: pointer;
    opacity: var(--o-tick);
    transition: opacity var(--dur-fast) linear;
  }

  .sort.right {
    justify-content: flex-end;
  }

  .sort:hover {
    opacity: 1;
  }

  .sort.on {
    opacity: 1;
  }

  .sort:focus-visible {
    outline: 1px solid var(--accent);
    outline-offset: var(--sp-2);
  }

  .arrow {
    opacity: 0;
    transition: opacity var(--dur-fast) linear;
  }

  .arrow.shown {
    opacity: 1;
  }

  .sort:hover .arrow {
    opacity: var(--o-hint);
  }

  .sort:hover .arrow.shown {
    opacity: 1;
  }

  @media (prefers-reduced-motion: reduce) {
    .sort,
    .arrow {
      transition: none;
    }
  }
</style>
