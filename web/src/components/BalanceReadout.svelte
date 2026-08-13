<script lang="ts">
  import { money } from "../lib/format";

  interface Props {
    balance: number;
    hidden?: boolean;
  }

  let { balance, hidden = false }: Props = $props();
</script>

<div class="balance" class:hidden>
  <span>Balance</span>
  <span class="num value">{money(balance)}</span>
</div>

<style>
  .hidden {
    visibility: hidden;
  }

  .balance {
    display: flex;
    justify-content: flex-end;
    align-items: baseline;
    gap: var(--sp-26);
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    opacity: var(--o-balance);
  }

  .value {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-label) * var(--fs-data-scale));
    opacity: 1;
  }
</style>