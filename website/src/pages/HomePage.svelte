<script lang="ts">
  import heroImage from '../assets/hero.png'
  import { docLinks, projectLinks, valueSections } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  let { navigate }: { navigate: (event: MouseEvent, href: string) => void } = $props()

  const cliExample =
    'excalibur-control-center-cli status\nexcalibur-control-center-cli gpu get\nexcalibur-control-center-cli keyboard get all\nexcalibur-control-center-cli doctor'
</script>

<section class="hero product-hero">
  <div>
    <p class="eyebrow">Linux controls for Casper Excalibur laptops</p>
    <h1>Excalibur Control Center for Linux.</h1>
    <p class="intro">
      cecc-linux provides a Rust CLI, a Slint GUI, packaging scripts, and the casper-wmi driver work
      needed for display mode, system profile, keyboard RGB, fan, and telemetry controls.
    </p>

    <div class="hero-actions" aria-label="Primary actions">
      <a class="button primary" href="/install" onclick={(event) => navigate(event, '/install')}>Install</a>
      <a class="button" href="/getting-started" onclick={(event) => navigate(event, '/getting-started')}>Get started</a>
    </div>
  </div>

  <img src={heroImage} alt="Excalibur Control Center interface preview" />
</section>

<section class="section value-grid" aria-label="Highlights">
  {#each valueSections as item}
    <article class="value-item">
      <h2>{item.title}</h2>
      <p>{item.body}</p>
    </article>
  {/each}
</section>

<section class="section example-section">
  <div>
    <p class="eyebrow">Works from the terminal too</p>
    <h2>Use structured commands for quick checks and scripts.</h2>
    <p>
      The CLI mirrors the useful parts of the GUI, so status checks and bug reports are easy to
      repeat.
    </p>
  </div>

  <CommandCard command={cliExample} className="inline-command-card" />
</section>

<section class="section status-strip" aria-label="Project scope">
  <div>
    <span>Userspace</span>
    <strong>Rust CLI and Slint GUI</strong>
  </div>
  <div>
    <span>Kernel</span>
    <strong>GPL casper-wmi driver</strong>
  </div>
  <div>
    <span>Delivery</span>
    <strong>Installer, DEB, and RPM paths</strong>
  </div>
</section>

<section class="section">
  <div class="section-heading">
    <p class="eyebrow">Documentation</p>
    <h2>Open the guide that matches your task.</h2>
  </div>

  <div class="doc-grid">
    {#each docLinks as item}
      <article class="doc-card">
        <h3>{item.title}</h3>
        <p>{item.body}</p>
        <a href={item.href} onclick={(event) => navigate(event, item.href)}>Open</a>
      </article>
    {/each}
  </div>
</section>

<section class="section community-section">
  <div>
    <p class="eyebrow">Project</p>
    <h2>Follow releases or report model-specific issues on GitHub.</h2>
  </div>

  <div class="project-links">
    {#each projectLinks as item}
      <a href={item.href}>{item.label}</a>
    {/each}
  </div>
</section>
