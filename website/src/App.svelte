<script lang="ts">
  import { tick } from 'svelte'
  import { navItems, type Page } from './content'
  import DevelopmentPage from './pages/DevelopmentPage.svelte'
  import DriverPage from './pages/DriverPage.svelte'
  import GettingStartedPage from './pages/GettingStartedPage.svelte'
  import GuiCliPage from './pages/GuiCliPage.svelte'
  import HomePage from './pages/HomePage.svelte'
  import InstallPage from './pages/InstallPage.svelte'
  import TroubleshootingPage from './pages/TroubleshootingPage.svelte'

  function pageFromPath(pathname: string): Page {
    switch (pathname.replace(/\/$/, '')) {
      case '/install':
        return 'install'
      case '/getting-started':
        return 'getting-started'
      case '/gui-cli':
        return 'gui-cli'
      case '/driver':
        return 'driver'
      case '/troubleshooting':
        return 'troubleshooting'
      case '/development':
        return 'development'
      default:
        return 'home'
    }
  }

  let currentPath = $state(window.location.pathname)
  let currentHash = $state(window.location.hash)
  const currentPage = $derived(pageFromPath(currentPath))

  $effect(() => {
    const syncPath = () => {
      currentPath = window.location.pathname
      currentHash = window.location.hash
    }

    window.addEventListener('popstate', syncPath)

    return () => {
      window.removeEventListener('popstate', syncPath)
    }
  })

  async function navigate(event: MouseEvent, href: string) {
    const url = new URL(href, window.location.origin)

    event.preventDefault()
    window.history.pushState(null, '', `${url.pathname}${url.hash}`)
    currentPath = url.pathname
    currentHash = url.hash

    await tick()

    if (currentHash) {
      document.querySelector(currentHash)?.scrollIntoView()
      return
    }

    window.scrollTo({ top: 0 })
  }
</script>

<main class="site-shell">
  <aside class="sidebar" aria-label="Documentation sections">
    <a
      class="brand"
      href="/"
      aria-label="CECC Linux documentation home"
      onclick={(event) => navigate(event, '/')}
    >
      <span class="brand-mark">CE</span>
      <span>
        <strong>cecc-linux</strong>
        <small>Excalibur Control Center</small>
      </span>
    </a>

    <nav>
      {#each navItems as item}
        <a
          class:active={item.page === currentPage}
          href={item.href}
          onclick={(event) => navigate(event, item.href)}
        >
          {item.label}
        </a>
      {/each}
    </nav>
  </aside>

  <div class="content">
    {#if currentPage === 'home'}
      <HomePage {navigate} />
    {:else if currentPage === 'install'}
      <InstallPage />
    {:else if currentPage === 'getting-started'}
      <GettingStartedPage />
    {:else if currentPage === 'gui-cli'}
      <GuiCliPage />
    {:else if currentPage === 'driver'}
      <DriverPage />
    {:else if currentPage === 'troubleshooting'}
      <TroubleshootingPage />
    {:else if currentPage === 'development'}
      <DevelopmentPage />
    {/if}
  </div>
</main>
