<script lang="ts">
  import type { GameId } from "../lib/types";
  import { GAME_LABELS } from "../lib/types";

  interface Props {
    game: GameId;
  }

  let { game }: Props = $props();
</script>

<h2>{GAME_LABELS[game]}</h2>

<style>
  h2 {
    margin: 0;
    font-family: var(--font-ui);
    font-size: var(--fs-nav);
    font-weight: var(--fw-regular);
    opacity: var(--o-nav-on);
  }
</style>