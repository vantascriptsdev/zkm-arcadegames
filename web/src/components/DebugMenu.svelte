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

  const GITHUB_URL = "https://github.com/vantascriptsdev/zkm-arcadegames/";
  const YOUTUBE_URL = "https://youtu.be/GmSRJ6o59Ho";

  type DebugView = GameId | "manager" | "creator";

  const VIEWS: { id: DebugView; label: string }[] = [
    ...GAME_IDS.map((id) => ({ id, label: GAME_LABELS[id] })),
    { id: "manager", label: "Manager" },
    { id: "creator", label: "Creator" },
  ];

  let activeView = $derived(
    arcade.admin.surface === "manager"
      ? "manager"
      : arcade.admin.surface === "placement"
        ? "creator"
        : arcade.session.game,
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

  onMount(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "F9") return;
      event.preventDefault();
      visible = !visible;
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
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
    <div class="debug-footer">
      <div class="debug-hints">
        <button type="button" class="hint-btn" onclick={() => (visible = false)}>
          <kbd>F9</kbd> / click to hide
        </button>
      </div>
      <div class="debug-links">
        <a class="link-btn" href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
        <a class="link-btn" href={YOUTUBE_URL} target="_blank" rel="noopener noreferrer">YouTube</a>
      </div>
    </div>
  </div>
{/if}

<style>
  .debug-menu {
    position: fixed;
    right: 1.1111vh;
    bottom: 1.1111vh;
    z-index: 1000;
    display: flex;
    flex-direction: column;
    gap: 0.5556vh;
    padding: 0.7407vh;
    background: rgba(8, 4, 10, 0.9);
    border-left: 2px solid var(--accent);
  }

  .debug-title {
    font-family: var(--font-mono);
    font-size: 1.4815vh;
    font-weight: var(--fw-medium);
    text-transform: uppercase;
    letter-spacing: var(--ls-caps);
    opacity: var(--o-muted);
  }

  .debug-buttons {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.3704vh;
  }

  button {
    appearance: none;
    border: 1px solid var(--divider);
    background: var(--surface-2);
    color: var(--ink);
    font-family: var(--font-mono);
    font-size: 1.4815vh;
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

  .debug-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.7407vh;
    margin-top: 0.1852vh;
    padding-top: 0.5556vh;
    border-top: 1px solid var(--divider);
  }

  .debug-hints {
    display: flex;
    align-items: center;
    gap: 0.7407vh;
  }

  .hint-btn {
    display: flex;
    align-items: center;
    gap: 0.3704vh;
    appearance: none;
    border: 0;
    background: transparent;
    padding: 0;
    font-family: var(--font-mono);
    font-size: 1.1111vh;
    font-weight: var(--fw-medium);
    text-transform: uppercase;
    letter-spacing: var(--ls-caps);
    color: var(--ink);
    opacity: var(--o-footer);
    cursor: pointer;
    transition: opacity var(--dur-fast) linear;
  }

  .hint-btn:hover {
    opacity: var(--o-nav-on);
  }

  kbd {
    font: inherit;
    line-height: 1;
    padding: 0.2778vh 0.5556vh;
    background: var(--surface-2);
    box-shadow: inset 0 0 0 1px var(--divider);
  }

  .debug-links {
    display: flex;
    gap: 0.3704vh;
  }

  .link-btn {
    display: inline-block;
    border: 1px solid var(--divider);
    background: var(--surface-2);
    color: var(--ink);
    font-family: var(--font-mono);
    font-size: 1.1111vh;
    font-weight: var(--fw-medium);
    text-transform: uppercase;
    letter-spacing: var(--ls-caps);
    text-decoration: none;
    white-space: nowrap;
    padding: 0.3704vh 0.7407vh;
    cursor: pointer;
    transition:
      opacity var(--dur-fast) linear,
      border-color var(--dur-fast) linear;
  }

  .link-btn:hover {
    opacity: 0.8;
    border-color: var(--accent);
  }
</style>