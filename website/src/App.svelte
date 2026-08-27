<script lang="ts">
  import { tick } from 'svelte'
  import { navItems, type Page } from './content'
  import AboutPage from './pages/AboutPage.svelte'
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
      case '/about':
        return 'about'
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

<main class="min-h-screen lg:grid lg:grid-cols-[280px_minmax(0,1fr)]">
  <aside
    class="flex flex-col border-b border-slate-200 bg-white p-5 dark:border-slate-700 dark:bg-slate-900 lg:sticky lg:top-0 lg:h-screen lg:border-r lg:border-b-0"
    aria-label="Documentation sections"
  >
    <a
      class="mb-8 flex items-center gap-3 no-underline"
      href="/"
      aria-label="CECC Linux documentation home"
      onclick={(event) => navigate(event, '/')}
    >
      <span
        class="grid h-10 w-10 place-items-center rounded-lg bg-slate-800 font-extrabold text-white dark:bg-slate-100 dark:text-slate-900"
      >
        CE
      </span>
      <span>
        <strong class="block leading-tight text-slate-950 dark:text-slate-50">cecc-linux</strong>
        <small class="mt-0.5 block text-[0.82rem] text-slate-500 dark:text-slate-400">
          Excalibur Control Center
        </small>
      </span>
    </a>

    <nav class="grid gap-1 max-lg:flex max-lg:flex-wrap">
      {#each navItems as item}
        <a
          class={[
            'rounded-md px-3 py-2 text-slate-600 no-underline hover:bg-slate-100 hover:text-slate-800 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-slate-100',
            item.page === currentPage && 'bg-slate-800 text-white hover:bg-slate-800 hover:text-white dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-100 dark:hover:text-slate-900',
          ]}
          href={item.href}
          onclick={(event) => navigate(event, item.href)}
        >
          {item.label}
        </a>
      {/each}
    </nav>

    <div class="mt-5 border-t border-slate-200 pt-5 dark:border-slate-700 lg:mt-auto">
      <a
        class="inline-flex min-h-10 w-full items-center justify-center rounded-lg border border-amber-600 bg-amber-600 px-4 py-2 text-sm font-extrabold text-white no-underline hover:border-amber-700 hover:bg-amber-700 dark:border-amber-400 dark:bg-amber-400 dark:text-slate-950 dark:hover:border-amber-300 dark:hover:bg-amber-300"
        href="https://github.com/sponsors/mert-kurttutan"
      >
        Sponsor development
      </a>
    </div>
  </aside>

  <div class="mx-auto w-full max-w-[1180px] px-5 py-8 sm:px-8 lg:px-16 lg:py-12">
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
    {:else if currentPage === 'about'}
      <AboutPage />
    {:else if currentPage === 'development'}
      <DevelopmentPage />
    {/if}
  </div>
</main>
