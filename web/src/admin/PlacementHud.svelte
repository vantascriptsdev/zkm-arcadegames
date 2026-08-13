<script lang="ts">
  import type { Admin } from "../state/admin.svelte";
  import { GAME_LABELS } from "../lib/types";
  import { coord, heading } from "../lib/format";
  import StatBlock from "../components/StatBlock.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";

  interface Props {
    admin: Admin;
  }

  let { admin }: Props = $props();

  let legend = $derived([
    { key: "W A S D", action: "Nudge position (hold)" },
    { key: "Q R", action: "Adjust height (hold)" },
    { key: "Z C", action: "Rotate (hold)" },
    { key: "F", action: "Snap to ground" },
    { key: "LMB", action: "Drag (hold)" },
    { key: "G", action: "Cycle game" },
    { key: "X", action: "Step size" },
    { key: "ENTER", action: admin.valid ? "Confirm" : "Confirm (unavailable)" },
    { key: "ESC", action: "Cancel" }
  ]);
</script>

<div class="hud" class:invalid={!admin.valid}>
  <div class="scrim top"></div>
  <div class="scrim bottom"></div>

  <div class="mode">
    <div class="eyebrow">
      <span class="dot"></span>
      <span>Machine creator</span>
    </div>
    <div class="headline">{admin.modeLabel}</div>
    <div class="validity">{admin.validityLabel}</div>
  </div>

  <div class="system meta">
    <div>{admin.mode === "move" ? "Repositioning" : "New machine"}</div>
    {#if admin.machines.length > 0}
      <div>{admin.machines.length} machines saved</div>
    {/if}
  </div>

  <div class="readout">
    <div class="readout-group">
      <div class="group-label">Position</div>
      <div class="coords">
        <div class="coord"><StatBlock plain size="lg" label="X" value={coord(admin.x)} /></div>
        <div class="coord"><StatBlock plain size="lg" label="Y" value={coord(admin.y)} /></div>
        <div class="coord"><StatBlock plain size="lg" label="Z" value={coord(admin.z)} /></div>
        <div class="coord wide">
          <StatBlock plain size="lg" label="Heading" value={heading(admin.heading)} />
        </div>
      </div>
    </div>

    <div class="context">
      <StatBlock plain size="sm" label="Game" value={GAME_LABELS[admin.placingGame]} accent />
      <StatBlock plain size="sm" label="Step" value={admin.stepLabel} />
    </div>
  </div>

  <div class="keys">
    <KeyLegend keys={legend} layout="grid" />
  </div>
</div>

<style>
  .hud {
    position: absolute;
    inset: 0;
    pointer-events: none;
    overflow: hidden;
    animation: fadeIn var(--dur-screen) linear;
  }

  .scrim {
    position: absolute;
    inset-inline: 0;
    height: 22cqh;
  }

  .scrim.top {
    top: 0;
    background: linear-gradient(rgba(4, 8, 10, 0.72), transparent);
  }

  .scrim.bottom {
    bottom: 0;
    background: linear-gradient(transparent, rgba(4, 8, 10, 0.72));
  }

  .mode {
    position: absolute;
    top: var(--sp-38);
    left: var(--sp-48);
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--sp-14);
    max-width: 44cqw;
  }

  .eyebrow {
    display: flex;
    align-items: center;
    gap: var(--sp-10);
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
  }

  .dot {
    width: 0.56cqh;
    height: 0.56cqh;
    background: var(--accent);
  }

  .hud.invalid .dot {
    background: var(--c-loss);
  }

  .headline {
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: clamp(22px, 3.7cqh, 80px);
    line-height: 1;
    color: var(--hero-ink);
  }

  .validity {
    background: var(--accent-tint);
    color: var(--accent);
    padding: var(--sp-8) var(--sp-12);
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
  }

  .hud.invalid .validity {
    background: var(--c-delete-edge);
    color: var(--c-loss);
  }

  .system {
    position: absolute;
    top: var(--sp-38);
    right: var(--sp-48);
    display: flex;
    flex-direction: column;
    gap: var(--sp-6);
    text-align: right;
    text-transform: uppercase;
    letter-spacing: var(--ls-caps);
  }

  .readout {
    position: absolute;
    left: var(--sp-48);
    bottom: var(--sp-32);
    display: flex;
    align-items: flex-end;
    gap: var(--sp-38);
    max-width: 60cqw;
  }

  .group-label {
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-muted);
  }

  .coords {
    display: flex;
    gap: var(--sp-26);
    margin-top: var(--sp-12);
  }

  .coord {
    min-width: 9.8cqh;
  }

  .coord.wide {
    min-width: 12cqh;
  }

  .context {
    display: flex;
    align-items: flex-end;
    gap: var(--sp-34);
  }

  .keys {
    position: absolute;
    right: var(--sp-48);
    bottom: var(--sp-32);
  }

  @media (prefers-reduced-motion: reduce) {
    .hud {
      animation: none;
    }
  }
</style>