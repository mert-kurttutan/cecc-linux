<script lang="ts">
  const installCommands = [
    {
      label: 'Debian / Ubuntu',
      command:
        'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center_0.1.33_amd64.deb\nsudo apt install ./excalibur-control-center_0.1.33_amd64.deb',
    },
    {
      label: 'Fedora / RPM',
      command:
        'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center-0.1.33-1.x86_64.rpm\nsudo dnf install ./excalibur-control-center-0.1.33-1.x86_64.rpm',
    },
    {
      label: 'Full installer',
      command:
        'curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | sudo bash',
    },
  ]

  const projectAreas = [
    {
      title: 'Control Center',
      body: 'Rust CLI and Slint GUI for display mode, system profile, keyboard RGB, fan, and hardware telemetry controls.',
      links: ['CLI usage', 'GUI usage', 'Support report'],
    },
    {
      title: 'casper-wmi Driver',
      body: 'Out-of-tree Linux WMI driver exposing Casper Excalibur controls through sysfs, LEDs, hwmon, and platform profiles.',
      links: ['DKMS install', 'NixOS reload flow', 'Sysfs permissions'],
    },
    {
      title: 'Troubleshooting',
      body: 'Model support notes and behavior references for display modes, LED brightness, custom titlebar behavior, and diagnostics.',
      links: ['Doctor report', 'Display modes', 'LED behavior'],
    },
  ]

  const quickLinks = [
    'Installation',
    'Driver',
    'CLI',
    'GUI',
    'Troubleshooting',
    'Development',
  ]
</script>

<main class="site-shell">
  <aside class="sidebar" aria-label="Documentation sections">
    <a class="brand" href="#top" aria-label="CECC Linux documentation home">
      <span class="brand-mark">CE</span>
      <span>
        <strong>cecc-linux</strong>
        <small>Excalibur Control Center</small>
      </span>
    </a>

    <nav>
      {#each quickLinks as link}
        <a href={`#${link.toLowerCase()}`}>{link}</a>
      {/each}
    </nav>
  </aside>

  <div class="content">
    <section class="hero" id="top">
      <p class="eyebrow">Linux hardware controls for Casper Excalibur laptops</p>
      <h1>Control Center documentation for users, testers, and driver development.</h1>
      <p class="intro">
        cecc-linux provides a Rust CLI, a Slint desktop GUI, packaging scripts, and the
        casper-wmi kernel driver work needed to expose Excalibur laptop controls on Linux.
      </p>

      <div class="hero-actions" aria-label="Primary actions">
        <a class="button primary" href="#installation">Install</a>
        <a class="button" href="#development">Develop</a>
      </div>
    </section>

    <section class="status-strip" aria-label="Project scope">
      <div>
        <span>Userspace</span>
        <strong>MIT licensed Rust workspace</strong>
      </div>
      <div>
        <span>Kernel</span>
        <strong>GPL casper-wmi driver</strong>
      </div>
      <div>
        <span>Delivery</span>
        <strong>DEB, RPM, and installer scripts</strong>
      </div>
    </section>

    <section class="section" id="installation">
      <div class="section-heading">
        <p class="eyebrow">Installation</p>
        <h2>Choose the package or full driver stack installer.</h2>
        <p>
          Packages install the GUI, CLI, udev rules, and permission helper. The full installer also
          handles the DKMS driver path.
        </p>
      </div>

      <div class="command-grid">
        {#each installCommands as item}
          <article class="command-card">
            <h3>{item.label}</h3>
            <pre><code>{item.command}</code></pre>
          </article>
        {/each}
      </div>

      <p class="note">
        After package installation, add your user to the <code>excalibur</code> group and log out
        and back in.
      </p>
    </section>

    <section class="section" id="driver">
      <div class="section-heading">
        <p class="eyebrow">Project Map</p>
        <h2>Documentation should follow the way people use the tool.</h2>
      </div>

      <div class="area-grid">
        {#each projectAreas as area}
          <article class="area-card">
            <h3>{area.title}</h3>
            <p>{area.body}</p>
            <ul>
              {#each area.links as link}
                <li>{link}</li>
              {/each}
            </ul>
          </article>
        {/each}
      </div>
    </section>

    <section class="section split" id="cli">
      <div>
        <p class="eyebrow">CLI</p>
        <h2>Common development commands</h2>
        <p>
          Rust workspace commands are run from <code>excalibur-control-center/</code>. The CLI can
          read status, GPU mode, keyboard zones, and support diagnostics.
        </p>
      </div>
      <pre><code>cd excalibur-control-center
cargo run -p excalibur-control-center-cli -- status
cargo run -p excalibur-control-center-cli -- gpu get
cargo run -p excalibur-control-center-cli -- keyboard get all
cargo run -p excalibur-control-center-cli -- doctor</code></pre>
    </section>

    <section class="section split" id="gui">
      <div>
        <p class="eyebrow">GUI</p>
        <h2>Desktop control surface</h2>
        <p>
          The GUI uses Slint and shares the same backend as the CLI. It exposes system mode,
          display mode, LED controls, troubleshooting output, and project credits.
        </p>
      </div>
      <pre><code>cd excalibur-control-center
cargo run -p excalibur-control-center-gui</code></pre>
    </section>

    <section class="section" id="troubleshooting">
      <div class="section-heading">
        <p class="eyebrow">Troubleshooting</p>
        <h2>Start with a read-only doctor report.</h2>
        <p>
          The doctor command collects kernel, DMI, WMI, driver, LED, and hwmon probes for bug
          reports without changing hardware state.
        </p>
      </div>
      <pre><code>cargo run -p excalibur-control-center-cli -- doctor
cargo run -p excalibur-control-center-cli -- doctor --include-dmesg</code></pre>
    </section>

    <section class="section split" id="development">
      <div>
        <p class="eyebrow">Development</p>
        <h2>Repo workflow</h2>
        <p>
          Use the Nix dev shell for kernel module dependencies and GUI runtime libraries. Hardware
          behavior checks currently live in Nushell scripts under <code>scripts/</code>.
        </p>
      </div>
      <pre><code>nix develop
cargo build
nu ./scripts/reload.nu</code></pre>
    </section>
  </div>
</main>
