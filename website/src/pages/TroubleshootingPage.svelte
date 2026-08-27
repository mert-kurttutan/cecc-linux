<script lang="ts">
  import { troubleshootingItems } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  const doctorCommand =
    'excalibur-control-center-cli doctor\nexcalibur-control-center-cli doctor --include-dmesg'
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">Troubleshooting</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      Start with a support report. The doctor command collects kernel, DMI, WMI, driver, LED, and
      hwmon probes for bug reports without changing hardware state.
    </p>
  </div>

  <div class="mx-auto grid max-w-[900px] grid-cols-1 gap-4">
    <CommandCard command={doctorCommand} className="text-left" />
    <ul class="grid gap-3 rounded-lg border border-slate-200 bg-white py-4 pr-4 pl-8 text-left dark:border-slate-700 dark:bg-slate-900">
      {#each troubleshootingItems as item}
        <li class="leading-relaxed text-slate-700 dark:text-slate-300">{item}</li>
      {/each}
    </ul>
  </div>
</section>
