<script lang="ts">
  interface Props {
    value: string;
    placeholder?: string;
    label: string;
    oninput: (value: string) => void;
  }

  let { value, placeholder = "", label, oninput }: Props = $props();
</script>

<div class="field">
  <span class="glyph" aria-hidden="true">⌕</span>
  <input
    type="text"
    {value}
    {placeholder}
    aria-label={label}
    spellcheck="false"
    autocomplete="off"
    oninput={(event) => oninput(event.currentTarget.value)}
  />
</div>

<style>
  .field {
    display: flex;
    align-items: center;
    gap: var(--sp-10);
    background: var(--surface-2);
    padding: 0 var(--sp-14);
  }

  .field:focus-within {
    box-shadow: inset 0 0 0 1px var(--accent);
  }

  .glyph {
    font-size: var(--fs-chip);
    opacity: var(--o-hint);
  }

  input {
    appearance: none;
    background: transparent;
    border: 0;
    outline: none;
    color: var(--ink);
    font-family: var(--font-ui);
    font-size: var(--fs-nav);
    font-weight: var(--fw-regular);
    padding: 1.02cqh 0;
    width: clamp(140px, 16cqh, 340px);
    cursor: text;
    user-select: text;
  }

  input::placeholder {
    color: var(--ink);
    opacity: var(--o-hint);
  }

  input:focus-visible {
    outline: none;
  }
</style>
