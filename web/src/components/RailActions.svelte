<script lang="ts">
  interface Props {
    primaryLabel: string;
    primaryDisabled?: boolean;
    onprimary: () => void;
    onback: () => void;
  }

  let { primaryLabel, primaryDisabled = false, onprimary, onback }: Props = $props();
</script>

<div class="actions">
  <button type="button" class="primary" disabled={primaryDisabled} onclick={onprimary}>
    {primaryLabel}
  </button>
  <button type="button" class="back quiet" onclick={onback}>Back</button>
</div>

<style>
  .actions {
    margin-top: auto;
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }

  .primary {
    appearance: none;
    border: 0;
    width: 100%;
    text-align: center;
    cursor: pointer;
    transition: opacity var(--dur-fast) linear;
    background: var(--accent);
    color: var(--on-accent);
    padding: var(--sp-16) 0;
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: var(--fs-tick);
  }

  .primary:hover:not(:disabled) {
    opacity: 0.88;
  }

  .primary:disabled {
    background: var(--surface-4);
    color: var(--ink);
    opacity: var(--o-hint);
    cursor: default;
  }

  .back {
    width: 100%;
    text-align: center;
    padding: 1.2cqh 0;
  }
</style>