<script lang="ts">
  import { driverCards } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>Driver</h1>
    <p class="intro">
      casper-wmi exposes Excalibur controls through Linux interfaces. It is the kernel-side piece
      for fan telemetry, keyboard LEDs, GPU/display mode, and platform profiles.
    </p>
  </div>

  <div class="area-grid page-stack">
    {#each driverCards as card}
      {#if card.command}
        <CommandCard title={card.title} body={card.body} command={card.command} className="area-card" />
      {/if}
    {/each}
  </div>
</section>
