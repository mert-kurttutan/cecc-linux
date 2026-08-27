<script lang="ts">
  import heroImage from '../assets/hero.png'
  import type { Locale, SiteContent } from '../content'
  import CommandCard from '../lib/CommandCard.svelte'

  let {
    content,
    locale,
    localizePath,
    navigate,
  }: {
    content: SiteContent
    locale: Locale
    localizePath: (locale: Locale, path: string) => string
    navigate: (event: MouseEvent, href: string) => void
  } = $props()

  const installHref = $derived(localizePath(locale, '/install'))
  const gettingStartedHref = $derived(localizePath(locale, '/getting-started'))
</script>

<section class="grid min-h-[min(680px,calc(100vh-6rem))] grid-cols-1 items-center gap-8 py-6 lg:grid-cols-[minmax(0,1fr)_minmax(260px,360px)] lg:gap-20">
  <div>
    <p class="mb-3 text-xs font-extrabold tracking-wider text-amber-700 uppercase dark:text-amber-400">{content.home.eyebrow}</p>
    <h1 class="mx-auto mb-4 max-w-[900px] text-[clamp(2.25rem,5vw,4.7rem)] leading-none font-bold text-slate-950 dark:text-slate-50">{content.home.title}</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      {content.home.intro}
    </p>

    <div class="mt-6 flex flex-wrap gap-3 max-sm:[&>a]:w-full" aria-label="Primary actions">
      <a class="inline-flex min-h-10 items-center justify-center rounded-lg border border-slate-800 bg-slate-800 px-4 py-2 font-bold text-white no-underline dark:border-slate-100 dark:bg-slate-100 dark:text-slate-900" href={installHref} onclick={(event) => navigate(event, installHref)}>{content.home.primaryCta}</a>
      <a class="inline-flex min-h-10 items-center justify-center rounded-lg border border-slate-300 bg-white px-4 py-2 font-bold text-slate-800 no-underline hover:border-slate-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-slate-400" href={gettingStartedHref} onclick={(event) => navigate(event, gettingStartedHref)}>{content.home.secondaryCta}</a>
    </div>
  </div>

  <img class="w-full max-w-[343px] justify-self-center rounded-lg border border-slate-200 bg-white dark:border-slate-700 dark:bg-slate-900" src={heroImage} alt={content.home.heroAlt} />
</section>

<section class="grid grid-cols-1 gap-5 pt-4 lg:grid-cols-3" aria-label="Highlights">
  {#each content.home.valueSections as item}
    <article class="py-4">
      <h2 class="mb-2 text-[clamp(1.35rem,2vw,1.75rem)] leading-tight font-bold text-slate-950 dark:text-slate-50">{item.title}</h2>
      <p class="leading-relaxed text-slate-600 dark:text-slate-400">{item.body}</p>
    </article>
  {/each}
</section>

<section class="grid grid-cols-1 items-start gap-6 pt-16 text-center lg:grid-cols-[minmax(0,0.82fr)_minmax(0,1fr)]">
  <div>
    <p class="mb-3 text-xs font-extrabold tracking-wider text-amber-700 uppercase dark:text-amber-400">{content.home.terminalEyebrow}</p>
    <h2 class="mb-3 text-[clamp(1.6rem,3vw,2.25rem)] leading-tight font-bold text-slate-950 dark:text-slate-50">{content.home.terminalTitle}</h2>
    <p class="leading-relaxed text-slate-600 dark:text-slate-400">
      {content.home.terminalBody}
    </p>
  </div>

  <CommandCard
    command={content.home.terminalCommand}
    copyLabel={content.commandCopy.copy}
    copiedLabel={content.commandCopy.copied}
    failedLabel={content.commandCopy.failed}
    copyAriaLabel={content.commandCopy.copyAria}
    copiedAriaLabel={content.commandCopy.copiedAria}
    failedAriaLabel={content.commandCopy.failedAria}
    className="text-left"
  />
</section>

<section class="mt-16 grid grid-cols-1 overflow-hidden rounded-lg border border-slate-200 bg-white dark:border-slate-700 dark:bg-slate-900 lg:grid-cols-3 [&>div]:p-4" aria-label="Project scope">
  {#each content.home.summary as item, index}
    <div class={index === 0 ? '' : 'border-t border-slate-200 dark:border-slate-700 lg:border-t-0 lg:border-l'}>
      <span class="mb-1 block text-xs font-extrabold text-slate-500 uppercase dark:text-slate-400">{item.label}</span>
      <strong class="block leading-snug text-slate-800 dark:text-slate-200">{item.value}</strong>
    </div>
  {/each}
</section>

<section class="pt-16">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <p class="mb-3 text-xs font-extrabold tracking-wider text-amber-700 uppercase dark:text-amber-400">{content.home.docsEyebrow}</p>
    <h2 class="mb-3 text-[clamp(1.6rem,3vw,2.25rem)] leading-tight font-bold text-slate-950 dark:text-slate-50">{content.home.docsTitle}</h2>
  </div>

  <div class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
    {#each content.docLinks as item}
      {@const href = localizePath(locale, item.href)}
      <article class="flex min-h-44 flex-col rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900">
        <h3 class="mb-2 text-base font-semibold text-slate-950 dark:text-slate-50">{item.title}</h3>
        <p class="mb-4 leading-relaxed text-slate-600 dark:text-slate-400">{item.body}</p>
        <a class="mt-auto font-extrabold text-slate-950 no-underline hover:text-amber-700 dark:text-slate-50 dark:hover:text-amber-400" href={href} onclick={(event) => navigate(event, href)}>{content.home.openLabel}</a>
      </article>
    {/each}
  </div>
</section>

<section class="grid grid-cols-1 items-start gap-6 pt-16 text-center lg:grid-cols-[minmax(0,0.9fr)_minmax(260px,0.8fr)]">
  <div>
    <p class="mb-3 text-xs font-extrabold tracking-wider text-amber-700 uppercase dark:text-amber-400">{content.home.projectEyebrow}</p>
    <h2 class="mb-3 text-[clamp(1.6rem,3vw,2.25rem)] leading-tight font-bold text-slate-950 dark:text-slate-50">{content.home.projectTitle}</h2>
  </div>

  <div class="grid overflow-hidden rounded-lg border border-slate-200 bg-white text-left dark:border-slate-700 dark:bg-slate-900">
    {#each content.projectLinks as item}
      <a class="border-t border-slate-200 p-4 font-extrabold text-slate-800 no-underline first:border-t-0 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800" href={item.href}>{item.label}</a>
    {/each}
  </div>
</section>
