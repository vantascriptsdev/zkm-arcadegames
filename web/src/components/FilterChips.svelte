<script lang="ts">
  interface Chip {
    id: string;
    label: string;
    count: number;
  }

  interface Props {
    chips: Chip[];
    active: string;
    onpick: (id: string) => void;
  }

  let { chips, active, onpick }: Props = $props();
</script>

<div class="chips">
  {#each chips as chip (chip.id)}
    <button
      type="button"
      class:on={chip.id === active}
      aria-pressed={chip.id === active}
      onclick={() => onpick(chip.id)}
    >
      <span>{chip.label}</span>
      <span class="num count">{chip.count}</span>
    </button>
  {/each}
</div>

<style>
  .chips {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    flex-wrap: wrap;
  }

  button {
    appearance: none;
    border: 0;
    display: flex;
    align-items: baseline;
    gap: var(--sp-8);
    font-family: var(--font-ui);
    color: var(--ink);
    background: var(--surface-2);
    padding: 0.83cqh 1.39cqh;
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
    cursor: pointer;
    transition:
      background var(--dur-fast) linear,
      opacity var(--dur-fast) linear;
  }

  button:hover {
    opacity: 0.8;
  }

  button:focus-visible {
    outline: 1px solid var(--accent);
    outline-offset: var(--sp-2);
    opacity: 1;
  }

  button.on {
    background: var(--accent-tint);
    color: var(--accent-bright);
    font-weight: var(--fw-semibold);
    opacity: 1;
  }

  .count {
    font-size: calc(var(--fs-label) * var(--fs-data-scale));
    opacity: var(--o-muted);
  }

  button.on .count {
    opacity: var(--o-nav-on);
  }

  @media (prefers-reduced-motion: reduce) {
    button {
      transition: none;
    }
  }
</style>
