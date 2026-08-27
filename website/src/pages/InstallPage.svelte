<script lang="ts">
  import { installOptions } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">Install</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      Install the package or the full driver stack. All options install the GUI, CLI, udev rules,
      and permission helper. Choose the full stack installer if you also need the casper-wmi DKMS
      driver.
    </p>
  </div>

  <div class="mx-auto grid w-full max-w-[900px] grid-cols-1 gap-4">
    {#each installOptions as option}
      {#if option.command}
        <CommandCard title={option.title} body={option.body} command={option.command} />
      {/if}
    {/each}
  </div>
</section>
