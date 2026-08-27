<script lang="ts">
  import type { SiteContent } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  let { content }: { content: SiteContent } = $props()
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">{content.gettingStarted.title}</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      {content.gettingStarted.intro}
    </p>
  </div>

  <div class="grid gap-4">
    {#each content.gettingStarted.steps as step, index}
      <article class="grid grid-cols-[auto_minmax(0,1fr)] gap-4 rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900">
        <span class="grid h-9 w-9 place-items-center rounded-lg bg-slate-800 font-extrabold text-white dark:bg-slate-100 dark:text-slate-900">{index + 1}</span>
        <div>
          <h3 class="mb-2 text-base font-semibold text-slate-950 dark:text-slate-50">{step.title}</h3>
          <p class="mb-4 leading-relaxed text-slate-600 dark:text-slate-400">{step.body}</p>
          {#if step.command}
            <CommandCard
              command={step.command}
              copyLabel={content.commandCopy.copy}
              copiedLabel={content.commandCopy.copied}
              failedLabel={content.commandCopy.failed}
              copyAriaLabel={content.commandCopy.copyAria}
              copiedAriaLabel={content.commandCopy.copiedAria}
              failedAriaLabel={content.commandCopy.failedAria}
              className="text-left"
            />
          {/if}
        </div>
      </article>
    {/each}
  </div>
</section>
