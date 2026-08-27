<script lang="ts">
  import { firstRunSteps } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'
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
          {#if step.command}
            <CommandCard command={step.command} className="inline-command-card" />
          {/if}
        </div>
      </article>
    {/each}
  </div>
</section>
