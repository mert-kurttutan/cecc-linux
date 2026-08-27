<script lang="ts">
  import { installOptions } from '../content'
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
      <article class="command-card">
        <div>
          <h3>{option.title}</h3>
          <p>{option.body}</p>
        </div>
        <pre><code>{option.command}</code></pre>
      </article>
    {/each}
  </div>
</section>
