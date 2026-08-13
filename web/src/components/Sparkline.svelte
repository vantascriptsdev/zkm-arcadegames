<script lang="ts">
  import { BASE_MULTIPLIER } from "../lib/types";

  type CurveMode = "live" | "cashed" | "crashed";

  interface Props {
    points: number[];
    mode: CurveMode;
  }

  let { points, mode }: Props = $props();

  const VIEWBOX_WIDTH = 1000;
  const VIEWBOX_HEIGHT = 400;
  const PLOT_INSET_RIGHT = 26;
  const BASELINE_INSET = 8;
  const MIN_PEAK = 1.4;
  const PEAK_HEADROOM = 1.14;
  const TIME_COMPRESSION = 1.55;
  const MIN_SPAN = 2;
  const PERCENT = 100;

  const instanceId = $props.id();
  const fadeId = "curve-fade-" + instanceId;

  const plotWidth = VIEWBOX_WIDTH - PLOT_INSET_RIGHT;
  const baseline = VIEWBOX_HEIGHT - BASELINE_INSET;

  let peak = $derived.by(() => {
    let highest = MIN_PEAK;
    for (const value of points) if (value > highest) highest = value;
    return highest * PEAK_HEADROOM;
  });

  let plotted = $derived.by(() => {
    const span = Math.max(MIN_SPAN, points.length) - 1;
    const rise = peak - BASE_MULTIPLIER;

    return points.map((value, index) => ({
      x: (index / span) ** TIME_COMPRESSION * plotWidth,
      y: baseline - ((value - BASE_MULTIPLIER) / rise) * baseline
    }));
  });

  let line = $derived(
    plotted
      .map((point, index) => `${index ? "L" : "M"}${point.x.toFixed(1)} ${point.y.toFixed(1)}`)
      .join(" ")
  );

  let area = $derived(`${line} L${plotWidth} ${baseline} L0 ${baseline} Z`);

  let head = $derived(plotted[plotted.length - 1]);
  let headLeft = $derived((head.x / VIEWBOX_WIDTH) * PERCENT);
  let headTop = $derived((head.y / VIEWBOX_HEIGHT) * PERCENT);
</script>

<div class="curve" class:cashed={mode === "cashed"} class:crashed={mode === "crashed"}>
  <svg viewBox="0 0 {VIEWBOX_WIDTH} {VIEWBOX_HEIGHT}" preserveAspectRatio="none">
    <defs>
      <linearGradient id={fadeId} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" style="stop-color: var(--curve-ink); stop-opacity: 0.34" />
        <stop offset="100%" style="stop-color: var(--curve-ink); stop-opacity: 0" />
      </linearGradient>
    </defs>
    <path class="fill" d={area} fill="url(#{fadeId})" />
    <path class="line" d={line} vector-effect="non-scaling-stroke" />
  </svg>

  <div class="tether" style:left="{headLeft}%" style:height="{headTop}%"></div>
  <div class="head" style:left="{headLeft}%" style:top="{headTop}%"></div>

  {#if mode === "crashed"}
    <div class="burst" style:left="{headLeft}%" style:top="{headTop}%"></div>
  {/if}
</div>

<style>
  .curve {
    position: relative;
    width: 100%;
    height: var(--curve-height);
    margin-top: var(--sp-20);
  }

  .curve.cashed {
    --curve-ink: var(--c-win);
    --curve-glow: var(--c-win-glow);
  }

  .curve.crashed {
    --curve-ink: var(--c-loss);
    --curve-glow: var(--c-loss-glow);
  }

  svg {
    display: block;
    width: 100%;
    height: 100%;
    overflow: visible;
  }

  .fill {
    stroke: none;
  }

  .line {
    fill: none;
    stroke: var(--curve-ink);
    stroke-width: 3;
    stroke-linejoin: round;
    stroke-linecap: round;
    transition: stroke var(--dur-fast) linear;
  }

  .curve.crashed .line {
    transition: none;
    animation: crash-hold var(--dur-crash-hold) linear forwards;
  }

  @keyframes crash-hold {
    0%,
    88% {
      opacity: 1;
    }
    100% {
      opacity: 0.72;
    }
  }

  .tether {
    position: absolute;
    top: 0;
    width: 1px;
    background: linear-gradient(to bottom, transparent, var(--curve-ink));
    opacity: 0.3;
    pointer-events: none;
  }

  .head {
    position: absolute;
    width: var(--curve-head-size);
    height: var(--curve-head-size);
    border-radius: 50%;
    background: var(--hero-ink);
    transform: translate(-50%, -50%);
    box-shadow:
      0 0 0 0.28cqh var(--curve-glow),
      0 0 2.6cqh var(--curve-glow);
  }

  .head::after {
    content: '';
    position: absolute;
    inset: calc(var(--curve-head-size) * -0.65);
    border-radius: 50%;
    border: 1px solid var(--curve-ink);
    animation: head-ring 1.2s var(--ease-out) infinite;
  }

  .curve.cashed .head::after,
  .curve.crashed .head::after {
    animation: none;
    opacity: 0;
  }

  @keyframes head-ring {
    0% {
      transform: scale(0.7);
      opacity: 0.55;
    }
    100% {
      transform: scale(1.4);
      opacity: 0;
    }
  }

  .curve.crashed .head {
    animation: head-burst var(--dur-head-burst) var(--ease-out) forwards;
  }

  @keyframes head-burst {
    0% {
      transform: translate(-50%, -50%) scale(1);
      opacity: 1;
    }
    40% {
      transform: translate(-50%, -50%) scale(2.6);
      opacity: 1;
    }
    100% {
      transform: translate(-50%, -50%) scale(3.6);
      opacity: 0;
    }
  }

  .burst {
    position: absolute;
    width: var(--curve-head-size);
    height: var(--curve-head-size);
    border-radius: 50%;
    border: var(--sp-2) solid var(--c-loss);
    transform: translate(-50%, -50%);
    pointer-events: none;
    animation: burst-ring var(--dur-head-burst) var(--ease-out) forwards;
  }

  @keyframes burst-ring {
    0% {
      transform: translate(-50%, -50%) scale(0.6);
      opacity: 0.95;
    }
    100% {
      transform: translate(-50%, -50%) scale(5);
      opacity: 0;
    }
  }
</style>
