<script lang="ts">
  import { devCommands } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>Development</h1>
    <p class="intro">
      Workflow commands for app, driver, and website changes. Use these when working on the Rust
      workspace, reloading the local driver, or changing this documentation site.
    </p>
  </div>

  <div class="command-grid page-stack">
    {#each devCommands as group}
      {#if group.command}
        <CommandCard title={group.title} command={group.command} />
      {/if}
    {/each}
  </div>
</section>
