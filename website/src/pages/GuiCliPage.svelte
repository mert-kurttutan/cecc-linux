<script lang="ts">
  import { workflowCards } from '../content'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>GUI & CLI</h1>
    <p class="intro">Use the GUI for daily control and the CLI for repeatable checks.</p>
  </div>

  <div class="area-grid page-stack">
    {#each workflowCards as card}
      <article class="area-card">
        <h3>{card.title}</h3>
        <p>{card.body}</p>
        <pre><code>{card.command}</code></pre>
      </article>
    {/each}
  </div>
</section>
