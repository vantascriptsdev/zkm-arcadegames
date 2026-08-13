<script lang="ts">
  import type { Admin } from "../state/admin.svelte";
  import FilterChips from "../components/FilterChips.svelte";
  import SearchField from "../components/SearchField.svelte";
  import SortHeader from "../components/SortHeader.svelte";
  import KeyLegend from "../components/KeyLegend.svelte";
  import MachineRow from "./MachineRow.svelte";

  interface Props {
    admin: Admin;
  }

  let { admin }: Props = $props();

  const SKELETON_ROWS = [0, 1, 2, 3, 4, 5];

  const legend = [
    { key: "ESC", action: "Exit admin" }
  ];

  let countText = $derived(
    `Showing ${admin.rows.length} of ${admin.machines.length} · ${admin.occupiedCount} in use`
  );
</script>

<div class="screen admin">
  <div class="panel">
    <div class="title-bar">
      <div>
        <h1>Machine manager</h1>
      </div>
      <div class="title-actions">
        <button type="button" class="quiet" disabled={admin.busy} onclick={() => admin.reload()}>
          Reload
        </button>
        <button type="button" class="cta" disabled={admin.busy} onclick={() => admin.create()}>
          Add machine
        </button>
      </div>
    </div>

    <div class="controls">
      <FilterChips
        chips={admin.chips}
        active={admin.filter}
        onpick={(id) => admin.setFilter(id)}
      />
      <SearchField
        value={admin.query}
        label="Search machines by id, game or creator"
        placeholder="Search id, game, creator"
        oninput={(value) => admin.setQuery(value)}
      />
    </div>

    <div class="list scroll">
      {#if admin.loading}
        <div class="skeletons">
          {#each SKELETON_ROWS as index (index)}
            <div class="skeleton-row">
              <div class="bar w1"></div>
              <div class="bar w2"></div>
              <div class="bar w3"></div>
              <div class="bar w4"></div>
            </div>
          {/each}
          <div class="skeleton-foot">Loading machines…</div>
        </div>
      {:else if admin.isEmpty}
        <div class="empty">
          <h2>No machines saved</h2>
          <p>Place one in the world to get started.</p>
          <div class="empty-actions">
            <button
              type="button"
              class="cta"
              disabled={admin.busy}
              onclick={() => admin.create()}
            >
              Add machine
            </button>
          </div>
        </div>
      {:else}
        <div class="table">
          <div class="head">
            <SortHeader
              label="Id"
              active={admin.sortKey === "id"}
              direction={admin.sortDirection}
              onsort={() => admin.sort("id")}
            />
            <SortHeader
              label="Game"
              active={admin.sortKey === "game"}
              direction={admin.sortDirection}
              onsort={() => admin.sort("game")}
            />
            <div class="coord-head">
              <div>X</div>
              <div>Y</div>
              <div>Z</div>
            </div>
            <SortHeader
              label="Heading"
              align="right"
              active={admin.sortKey === "heading"}
              direction={admin.sortDirection}
              onsort={() => admin.sort("heading")}
            />
            <div class="author-head">Created by · when</div>
            <SortHeader
              label="State"
              active={admin.sortKey === "state"}
              direction={admin.sortDirection}
              onsort={() => admin.sort("state")}
            />
            <div class="actions-head">Actions</div>
          </div>

          {#key admin.filter}
            {#each admin.rows as machine, index (machine.id)}
              <MachineRow
                {machine}
                {index}
                busy={admin.busy}
                confirming={admin.confirmId === machine.id}
                blocked={admin.blockedId === machine.id}
                onteleport={() => admin.teleport(machine.id)}
                onmove={() => admin.move(machine.id)}
                onaskdelete={() => admin.askDelete(machine.id)}
                onconfirmdelete={() => admin.remove(machine.id)}
                ondismiss={() => admin.dismissPrompt()}
              />
            {/each}
          {/key}

          <div class="rule"></div>
        </div>
      {/if}
    </div>

    <div class="footer">
      <KeyLegend keys={legend} />
      <div class="meta count">{countText}</div>
    </div>
  </div>
</div>

<style>
  .admin {
    --backdrop: linear-gradient(#0a0f12 0%, #070b0d 100%);
    --col-id: clamp(48px, 5.93cqh, 130px);
    --col-heading: clamp(84px, 8.89cqh, 190px);
    --col-actions: clamp(140px, 12.6cqh, 300px);
    --table-cols:
      var(--col-id) minmax(0, 0.95fr) minmax(0, 1.35fr) var(--col-heading)
      minmax(0, 1.25fr) minmax(0, 1fr) var(--col-actions);
    overflow: hidden;
    opacity: 0.97;
  }

  .panel {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    gap: var(--sp-26);
    padding: var(--pad-screen);
  }

  .title-bar {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: var(--sp-38);
    flex: 0 0 auto;
  }

  h1 {
    margin: var(--sp-12) 0 0;
    font-family: var(--font-display);
    font-weight: var(--fw-display);
    font-size: clamp(28px, 4.26cqh, 92px);
    line-height: 1;
    letter-spacing: var(--ls-display-tight);
    color: var(--hero-ink);
  }

  .title-actions {
    display: flex;
    align-items: center;
    gap: var(--sp-16);
    flex: 0 0 auto;
  }

  .title-actions .quiet:disabled,
  .cta:disabled {
    cursor: default;
  }

  .controls {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-16);
    flex-wrap: wrap;
    flex: 0 0 auto;
  }

  .list {
    flex: 1 1 auto;
    min-height: 0;
  }

  .head {
    display: grid;
    grid-template-columns: var(--table-cols);
    align-items: baseline;
    gap: var(--sp-14);
    padding: 0 0 var(--sp-12) var(--sp-14);
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-muted);
  }

  .coord-head {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--sp-12);
    text-align: right;
    min-width: 0;
  }

  .author-head,
  .actions-head {
    white-space: nowrap;
  }

  .actions-head {
    text-align: right;
  }

  .rule {
    border-top: 1px solid var(--divider);
  }

  .skeletons {
    display: flex;
    flex-direction: column;
  }

  .skeleton-row {
    border-top: 1px solid var(--divider);
    padding: var(--sp-20) 0;
    display: flex;
    gap: var(--sp-24);
    align-items: center;
  }

  .bar {
    height: 1.02cqh;
  }

  .w1 {
    width: 6.85cqh;
    background: var(--surface-6);
  }

  .w2 {
    width: 11.1cqh;
    background: var(--surface-4);
  }

  .w3 {
    flex: 1;
    max-width: 25.9cqh;
    background: var(--surface-3);
  }

  .w4 {
    width: 8.33cqh;
    background: var(--surface-1);
  }

  .skeleton-foot {
    border-top: 1px solid var(--divider);
    padding: var(--sp-20) 0;
    font-size: var(--fs-meta);
    font-weight: var(--fw-regular);
    opacity: var(--o-hint);
  }

  .empty {
    border-top: 1px solid var(--divider);
    padding: var(--sp-48) 0 0;
    display: flex;
    flex-direction: column;
    gap: var(--sp-18);
    align-items: flex-start;
  }

  h2 {
    margin: 0;
    font-family: var(--font-ui);
    font-weight: var(--fw-semibold);
    font-size: var(--fs-stat-lg);
    color: var(--resolved-ink);
  }

  p {
    margin: 0;
    max-width: 38cqh;
    font-size: var(--fs-chip);
    font-weight: var(--fw-regular);
    opacity: var(--o-body);
  }

  .empty-actions {
    display: flex;
    gap: var(--sp-2);
    margin-top: var(--sp-6);
  }

  .footer {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--sp-30);
    flex: 0 0 auto;
  }

  .count {
    opacity: var(--o-meta);
  }

  .cta:focus-visible,
  .quiet:focus-visible {
    outline: 1px solid var(--accent);
    outline-offset: var(--sp-2);
  }

  @container admin (max-width: 1180px) {
    .admin {
      --table-cols:
        var(--col-id) minmax(0, 0.95fr) minmax(0, 1.5fr) var(--col-heading)
        minmax(0, 1.05fr) var(--col-actions);
    }

    .author-head {
      display: none;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .screen {
      animation: none;
      transition: none;
    }
  }
</style>