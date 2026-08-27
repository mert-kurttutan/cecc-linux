<script lang="ts">
  import { workflowCards } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>GUI & CLI</h1>
    <p class="intro">Use the GUI for daily control and the CLI for repeatable checks.</p>
  </div>

  <div class="area-grid page-stack">
    {#each workflowCards as card}
      {#if card.command}
        <CommandCard title={card.title} body={card.body} command={card.command} className="area-card" />
      {/if}
    {/each}
  </div>
</section>
