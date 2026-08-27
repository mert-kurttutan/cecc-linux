<script lang="ts">
  import type { SiteContent } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  let { content }: { content: SiteContent } = $props()
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">{content.guiCli.title}</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">{content.guiCli.intro}</p>
  </div>

  <div class="mx-auto grid max-w-[900px] grid-cols-1 gap-4">
    {#each content.guiCli.cards as card}
      {#if card.command}
        <CommandCard
          title={card.title}
          body={card.body}
          command={card.command}
          copyLabel={content.commandCopy.copy}
          copiedLabel={content.commandCopy.copied}
          failedLabel={content.commandCopy.failed}
          copyAriaLabel={content.commandCopy.copyAria}
          copiedAriaLabel={content.commandCopy.copiedAria}
          failedAriaLabel={content.commandCopy.failedAria}
        />
      {/if}
    {/each}
  </div>
</section>
