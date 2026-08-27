<script lang="ts">
  import { aboutItems, creditItems } from '../content'
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl text-center">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-none font-bold text-amber-700 dark:text-amber-400">About</h1>
    <p class="mx-auto max-w-3xl text-lg leading-relaxed text-slate-600 dark:text-slate-400">
      Project information and credits from the Excalibur Control Center desktop app.
    </p>
  </div>

  <div class="mx-auto grid max-w-[900px] grid-cols-1 gap-4">
    <article class="rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900">
      <h2 class="mb-3 text-xl leading-tight font-bold text-slate-950 dark:text-slate-50">Project</h2>
      <ul class="grid gap-3 pl-5">
        {#each aboutItems as item}
          <li class="leading-relaxed text-slate-700 dark:text-slate-300">{item}</li>
        {/each}
      </ul>
    </article>

    <article class="rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900">
      <h2 class="mb-3 text-xl leading-tight font-bold text-slate-950 dark:text-slate-50">Credits</h2>
      <div class="grid overflow-hidden rounded-lg border border-slate-200 dark:border-slate-700">
        {#each creditItems as item}
          <a
            class="border-t border-slate-200 p-4 font-extrabold text-slate-800 no-underline first:border-t-0 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"
            href={item.href}
          >
            {item.label}
          </a>
        {/each}
      </div>
    </article>

    <article class="rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900">
      <h2 class="mb-3 text-xl leading-tight font-bold text-slate-950 dark:text-slate-50">License</h2>
      <p class="leading-relaxed text-slate-700 dark:text-slate-300">
        The userspace application is MIT licensed. The kernel driver code is GPL-2.0-or-later, as
        marked in the driver source.
      </p>
    </article>
  </div>
</section>
