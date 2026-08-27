<script lang="ts">
  import { troubleshootingItems } from '../content'
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
    <pre><code>excalibur-control-center-cli doctor
excalibur-control-center-cli doctor --include-dmesg</code></pre>
    <ul>
      {#each troubleshootingItems as item}
        <li>{item}</li>
      {/each}
    </ul>
  </div>
</section>
