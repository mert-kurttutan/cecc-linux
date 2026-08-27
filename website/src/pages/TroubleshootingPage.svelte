<script lang="ts">
  import { troubleshootingItems } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  const doctorCommand =
    'excalibur-control-center-cli doctor\nexcalibur-control-center-cli doctor --include-dmesg'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>Troubleshooting</h1>
    <p class="intro">
      Start with a support report. The doctor command collects kernel, DMI, WMI, driver, LED, and
      hwmon probes for bug reports without changing hardware state.
    </p>
  </div>

  <div class="check-panel page-stack">
    <CommandCard command={doctorCommand} className="inline-command-card" />
    <ul>
      {#each troubleshootingItems as item}
        <li>{item}</li>
      {/each}
    </ul>
  </div>
</section>
