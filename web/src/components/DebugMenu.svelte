<script lang="ts">
  import { onMount } from "svelte";
  import type { Arcade } from "../state/arcade.svelte";
  import type { GameId } from "../lib/types";
  import { GAME_IDS, GAME_LABELS } from "../lib/types";
  import { inNui } from "../lib/nui";

  interface Props {
    arcade: Arcade;
  }

  let { arcade }: Props = $props();

  let visible = $state(true);

  onMount(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "F9") return;
      event.preventDefault();
      visible = !visible;
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  type DebugView = GameId | "manager" | "creator";

  const VIEWS: { id: DebugView; label: string }[] = [
    ...GAME_IDS.map((id) => ({ id, label: GAME_LABELS[id] })),
    { id: "manager", label: "Manager" },
    { id: "creator", label: "Creator" }
  ];

  let activeView = $derived(
    arcade.admin.surface === "manager"
      ? "manager"
      : arcade.admin.surface === "placement"
        ? "creator"
        : arcade.session.game
  );

  function showGame(game: GameId) {
    arcade.admin.surface = "none";
    if (game !== arcade.session.game) {
      arcade.active.reset();
      arcade.session.game = game;
    }
    arcade.session.visible = true;
    arcade.session.limitBet();
  }

  function showManager() {
    arcade.admin.surface = "manager";
  }

  function showCreator() {
    arcade.admin.mode = "new";
    arcade.admin.placingId = null;
    arcade.admin.surface = "placement";
  }

  function select(view: DebugView) {
    if (view === "manager") return showManager();
    if (view === "creator") return showCreator();
    showGame(view);
  }
</script>

{#if !inNui && visible}
  <div class="debug-menu">
    <div class="debug-title">Debug</div>
    <div class="debug-buttons">
      {#each VIEWS as view (view.id)}
        <button
          type="button"
          class:active={activeView === view.id}
          onclick={() => select(view.id)}
        >
          {view.label}
        </button>
      {/each}
    </div>
  </div>
{/if}

<style>
  .debug-menu {
    position: fixed;
    right: 12px;
    bottom: 12px;
    z-index: 1000;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 0.7407vh;
    background: rgba(8, 4, 10, 0.9);
    border-left: 2px solid var(--accent);
  }

  .debug-title {
    font-family: var(--font-mono);
    font-size: 0.7407vh;
    font-weight: var(--fw-medium);
    text-transform: uppercase;
    letter-spacing: var(--ls-caps);
    opacity: var(--o-muted);
  }

  .debug-buttons {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
  }

  button {
    appearance: none;
    border: 1px solid var(--divider);
    background: var(--surface-2);
    color: var(--ink);
    font-family: var(--font-mono);
    font-size: 0.7407vh;
    cursor: pointer;
    white-space: nowrap;
    transition: opacity var(--dur-fast) linear;
  }

  button:hover {
    opacity: 0.8;
  }

  button.active {
    background: var(--accent);
    color: var(--on-accent);
    border-color: var(--accent);
  }
</style>
