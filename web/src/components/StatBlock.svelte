<script lang="ts">
  interface Props {
    label: string;
    value: string;
    align?: "left" | "right";
    accent?: boolean;
    size?: "sm" | "md" | "lg";
    plain?: boolean;
  }

  let { label, value, align = "left", accent = false, size = "md", plain = false }: Props =
    $props();
</script>

<div class="stat" class:right={align === "right"} class:plain>
  <div class="key">{label}</div>
  <div class="num value" class:accent class:sm={size === "sm"} class:lg={size === "lg"}>
    {value}
  </div>
</div>

<style>
  .stat {
    background: var(--surface-1);
    padding: var(--sp-16) var(--sp-18);
  }

  .stat.plain {
    background: none;
    padding: 0;
  }

  .stat.right {
    text-align: right;
  }

  .key {
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
  }

  .value {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-stat) * var(--fs-data-scale));
    margin-top: var(--sp-6);
  }

  .value.sm {
    font-weight: var(--fw-regular);
    font-size: calc(var(--fs-stat-sm) * var(--fs-data-scale));
  }

  .value.lg {
    font-weight: var(--fw-medium);
    font-size: calc(var(--fs-coord) * var(--fs-data-scale));
  }

  .value.accent {
    color: var(--accent);
  }
</style>
