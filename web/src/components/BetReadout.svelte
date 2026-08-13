<script lang="ts">
  import { money } from "../lib/format";

  interface Props {
    bet: number;
  }

  let { bet }: Props = $props();
</script>

<div class="head">
  <div class="label">Bet</div>
  <div class="num amount">{money(bet)}</div>
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
</style>
