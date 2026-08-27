<script lang="ts">
  import { firstRunSteps } from '../content'
</script>

<section class="hero page-hero">
  <div class="section-heading">
    <h1>Getting Started</h1>
    <p class="intro">
      Verify access before changing hardware state. These are the first checks to run after
      installing the package or the full stack.
    </p>
  </div>

  <div class="step-list">
    {#each firstRunSteps as step, index}
      <article class="step-card">
        <span>{index + 1}</span>
        <div>
          <h3>{step.title}</h3>
          <p>{step.body}</p>
          <pre><code>{step.command}</code></pre>
        </div>
      </article>
    {/each}
  </div>
</section>
