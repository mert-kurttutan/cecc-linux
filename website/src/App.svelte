<script lang="ts">
  import { goto } from '$app/navigation'
  import { page } from '$app/state'
  import { localizePath, siteContent, stripLocalePath, type Locale, type Page, type SiteContent } from './content'
  import AboutPage from './pages/AboutPage.svelte'
  import DevelopmentPage from './pages/DevelopmentPage.svelte'
  import DriverPage from './pages/DriverPage.svelte'
  import GettingStartedPage from './pages/GettingStartedPage.svelte'
  import GuiCliPage from './pages/GuiCliPage.svelte'
  import HomePage from './pages/HomePage.svelte'
  import InstallPage from './pages/InstallPage.svelte'
  import TroubleshootingPage from './pages/TroubleshootingPage.svelte'

  function pageFromPath(path: string): Page {
    switch (path.replace(/\/$/, '') || '/') {
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

  function descriptionForPage(page: Page, content: SiteContent) {
    switch (page) {
      case 'install':
        return content.install.intro
      case 'getting-started':
        return content.gettingStarted.intro
      case 'gui-cli':
        return content.guiCli.intro
      case 'driver':
        return content.driver.intro
      case 'troubleshooting':
        return content.troubleshooting.intro
      case 'about':
        return content.about.intro
      case 'development':
        return content.development.intro
      default:
        return content.home.intro
    }
  }

  const currentPath = $derived(page.url.pathname)
  const currentHash = $derived(page.url.hash)
  const currentRoute = $derived(stripLocalePath(currentPath))
  const currentLocale = $derived(currentRoute.locale)
  const currentContent = $derived(siteContent[currentLocale])
  const currentPage = $derived(pageFromPath(currentRoute.path))
  const alternateLocale = $derived<Locale>(currentLocale === 'en' ? 'tr' : 'en')
  const alternateHref = $derived(localizePath(alternateLocale, currentRoute.path))
  const canonicalHref = $derived(localizePath(currentLocale, currentRoute.path))
  const currentPageTitle = $derived(currentContent.navItems.find((item) => item.page === currentPage)?.label ?? 'cecc-linux')
  const currentDescription = $derived(descriptionForPage(currentPage, currentContent))

  $effect(() => {
    document.documentElement.lang = currentLocale
  })

  $effect(() => {
    if (currentRoute.path !== '/' && currentPage === 'home') {
      return
    }

    if (canonicalHref === currentPath) {
      return
    }

    goto(`${canonicalHref}${currentHash}`, {
      replaceState: true,
      noScroll: true,
      keepFocus: true,
    })
  })

</script>

<svelte:head>
  <title>{currentPageTitle} | cecc-linux</title>
  <meta name="description" content={currentDescription} />
  <link rel="canonical" href={canonicalHref} />
  <link rel="alternate" hreflang="en" href={localizePath('en', currentRoute.path)} />
  <link rel="alternate" hreflang="tr" href={localizePath('tr', currentRoute.path)} />
</svelte:head>

<main class="min-h-screen lg:grid lg:grid-cols-[280px_minmax(0,1fr)]">
  <aside
    class="flex flex-col border-b border-slate-200 bg-white p-5 dark:border-slate-700 dark:bg-slate-900 lg:sticky lg:top-0 lg:h-screen lg:border-r lg:border-b-0"
    aria-label="Documentation sections"
  >
    <a
      class="mb-8 flex items-center gap-3 no-underline"
      href={localizePath(currentLocale, '/')}
      aria-label="CECC Linux documentation home"
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
      {#each currentContent.navItems as item}
        {@const href = localizePath(currentLocale, item.href)}
        <a
          class={[
            'rounded-md px-3 py-2 text-slate-600 no-underline hover:bg-slate-100 hover:text-slate-800 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-slate-100',
            item.page === currentPage && 'bg-slate-800 text-white hover:bg-slate-800 hover:text-white dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-100 dark:hover:text-slate-900',
          ]}
          href={href}
        >
          {item.label}
        </a>
      {/each}
    </nav>

    <div class="mt-5 grid gap-3 border-t border-slate-200 pt-5 dark:border-slate-700 lg:mt-auto">
      <a
        class="inline-flex min-h-10 w-full items-center justify-center rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-extrabold text-slate-800 no-underline hover:border-slate-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-slate-400"
        href={alternateHref}
        hreflang={alternateLocale}
      >
        {currentContent.languageSwitchLabel}
      </a>
      <a
        class="inline-flex min-h-10 w-full items-center justify-center rounded-lg border border-amber-600 bg-amber-600 px-4 py-2 text-sm font-extrabold text-white no-underline hover:border-amber-700 hover:bg-amber-700 dark:border-amber-400 dark:bg-amber-400 dark:text-slate-950 dark:hover:border-amber-300 dark:hover:bg-amber-300"
        href="https://github.com/sponsors/mert-kurttutan"
      >
        {currentContent.sponsorLabel}
      </a>
    </div>
  </aside>

  <div class="mx-auto w-full max-w-[1180px] px-5 py-8 sm:px-8 lg:px-16 lg:py-12">
    {#if currentPage === 'home'}
      <HomePage content={currentContent} locale={currentLocale} {localizePath} />
    {:else if currentPage === 'install'}
      <InstallPage content={currentContent} />
    {:else if currentPage === 'getting-started'}
      <GettingStartedPage content={currentContent} />
    {:else if currentPage === 'gui-cli'}
      <GuiCliPage content={currentContent} />
    {:else if currentPage === 'driver'}
      <DriverPage content={currentContent} />
    {:else if currentPage === 'troubleshooting'}
      <TroubleshootingPage content={currentContent} />
    {:else if currentPage === 'about'}
      <AboutPage content={currentContent} />
    {:else if currentPage === 'development'}
      <DevelopmentPage content={currentContent} />
    {/if}
  </div>
</main>
