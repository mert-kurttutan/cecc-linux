<script lang="ts">
  import { driverCards } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">Driver</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      casper-wmi exposes Excalibur controls through Linux interfaces. It is the kernel-side piece
      for fan telemetry, keyboard LEDs, GPU/display mode, and platform profiles.
    </p>
  </div>

  <div class="mx-auto grid max-w-[900px] grid-cols-1 gap-4">
    {#each driverCards as card}
      {#if card.command}
        <CommandCard title={card.title} body={card.body} command={card.command} />
      {/if}
    {/each}
  </div>
</section>
