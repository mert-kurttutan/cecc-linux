<script lang="ts">
  import { installOptions } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>Install</h1>
    <p class="intro">
      Install the package or the full driver stack. All options install the GUI, CLI, udev rules,
      and permission helper. Choose the full stack installer if you also need the casper-wmi DKMS
      driver.
    </p>
  </div>

  <div class="command-grid install-grid">
    {#each installOptions as option}
      {#if option.command}
        <CommandCard title={option.title} body={option.body} command={option.command} />
      {/if}
    {/each}
  </div>
</section>
