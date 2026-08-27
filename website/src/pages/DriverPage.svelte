<script lang="ts">
  import { driverCards } from '../content'
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
      <article class="area-card">
        <h3>{card.title}</h3>
        <p>{card.body}</p>
        <pre><code>{card.command}</code></pre>
      </article>
    {/each}
  </div>
</section>
