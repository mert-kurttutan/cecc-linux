<script lang="ts">
  import { workflowCards } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">GUI & CLI</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">Use the GUI for daily control and the CLI for repeatable checks.</p>
  </div>

  <div class="mx-auto grid max-w-[900px] grid-cols-1 gap-4">
    {#each workflowCards as card}
      {#if card.command}
        <CommandCard title={card.title} body={card.body} command={card.command} />
      {/if}
    {/each}
  </div>
</section>
