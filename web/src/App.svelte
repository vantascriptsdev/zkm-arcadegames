<script lang="ts">
  import { onMount } from "svelte";
  import { Arcade } from "./state/arcade.svelte";
  import Crash from "./games/Crash.svelte";
  import Plinko from "./games/Plinko.svelte";
  import HigherOrLower from "./games/HigherOrLower.svelte";
  import Mines from "./games/Mines.svelte";
  import MachineManager from "./admin/MachineManager.svelte";
  import PlacementHud from "./admin/PlacementHud.svelte";
  import DebugMenu from "./components/DebugMenu.svelte";
  import { inNui } from "./lib/nui";

  const arcade = new Arcade();

  onMount(() => arcade.mount());

  const FALLBACK_SCREEN_RECT = { x: 0.235, y: 0.14, w: 1.0, h: 1.0 };

  let playing = $derived(arcade.session.mode === "play");
  let rect = $derived(playing ? (arcade.session.rect ?? FALLBACK_SCREEN_RECT) : null);

  let frameStyle = $derived(
    rect
      ? `left:${rect.x * 100}%;top:${rect.y * 100}%;width:${rect.w * 100}%;height:${rect.h * 100}%;`
      : "left:0;top:0;width:100%;height:100%;"
  );
</script>

{#if arcade.admin.surface !== "none"}
  <div
    class="admin-root"
    class:overlay={arcade.admin.surface === "placement"}
    class:dev-backdrop={!inNui}
  >
    {#if arcade.admin.surface === "manager"}
      <MachineManager admin={arcade.admin} />
    {:else}
      <PlacementHud admin={arcade.admin} />
    {/if}
  </div>
{/if}

{#if arcade.session.visible && arcade.admin.surface === "none"}
  <div class="frame" class:playing style={frameStyle}>
    <main>
      {#if arcade.session.game === "crash"}
        <Crash {arcade} />
      {:else if arcade.session.game === "plinko"}
        <Plinko {arcade} />
      {:else if arcade.session.game === "mines"}
        <Mines {arcade} />
      {:else}
        <HigherOrLower {arcade} />
      {/if}

      {#if arcade.session.notice}
        <div class="notice"><span>{arcade.session.notice}</span></div>
      {/if}

      {#if arcade.session.spectating}
        <div class="watching">
          <span>{arcade.session.spectateWaiting ? "Round in progress" : "Watching"}</span>
        </div>
      {/if}

      {#if arcade.session.showOccupiedOverlay}
        <div class="occupied"><span>In use</span></div>
      {/if}
    </main>
  </div>
{/if}

<DebugMenu {arcade} />

<style>
  .admin-root {
    position: fixed;
    inset: 0;
    container: admin / size;
    font-family: var(--font-ui);
    z-index: 1;
  }

  .admin-root.overlay {
    pointer-events: none;
  }

  .admin-root.dev-backdrop {
    background: #333;
  }

  .frame {
    position: fixed;
    overflow: hidden;
    border-radius: 7.4074vh;
  }

  .frame.playing {
    animation: frame-in 220ms ease-out both;
  }

  main {
    container-type: size;
    container-name: stage;
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-ui);
  }

  .notice {
    position: absolute;
    inset-inline: 0;
    top: 6cqh;
    display: flex;
    justify-content: center;
    pointer-events: none;
    animation: notice-in 160ms ease-out both;
  }

  .notice span {
    background: rgba(8, 4, 10, 0.9);
    border-left: 2px solid var(--accent);
    padding: 1.1cqh 2cqh;
    color: var(--ink);
    font-size: 2.1cqh;
  }

  .watching {
    position: absolute;
    top: var(--sp-44);
    right: var(--sp-64);
    display: flex;
    align-items: center;
    gap: var(--sp-8);
    pointer-events: none;
  }

  .watching::before {
    content: '';
    width: 0.65cqh;
    height: 0.65cqh;
    border-radius: 50%;
    background: var(--accent);
    animation: watching-pulse 1.8s ease-in-out infinite;
  }

  .watching span {
    font-size: var(--fs-label);
    font-weight: var(--fw-regular);
    color: var(--accent);
    opacity: var(--o-nav-on);
  }

  @keyframes watching-pulse {
    50% {
      opacity: 0.25;
    }
  }

  .occupied {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    background: rgba(4, 2, 6, 0.8);
  }

  .occupied span {
    padding: 0.5em 1.4em;
    border: 2px solid rgba(255, 60, 60, 0.9);
    border-radius: 4px;
    color: rgb(255, 90, 90);
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: 5.5cqh;
    animation: occupied-pulse 1.6s ease-in-out infinite;
  }

  @keyframes occupied-pulse {
    50% {
      opacity: 0.45;
    }
  }

  @keyframes notice-in {
    from {
      opacity: 0;
      transform: translateY(-0.6cqh);
    }
    to {
      opacity: 1;
      transform: none;
    }
  }

  @keyframes frame-in {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
</style>