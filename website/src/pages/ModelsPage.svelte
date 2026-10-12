<script lang="ts">
  import type { SiteContent } from '../content'

  let { content }: { content: SiteContent } = $props()
</script>

<section class="py-2 text-center">
  <div class="mx-auto mb-6 max-w-3xl">
    <h1 class="mx-auto mb-4 text-[clamp(2rem,4vw,3.6rem)] leading-tight font-bold text-amber-700 dark:text-amber-400">
      {content.models.title}
    </h1>
  </div>

  <div class="mx-auto max-w-[760px] overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
    <table class="w-full border-collapse text-left">
      <thead class="bg-slate-100 text-sm text-slate-700 dark:bg-slate-800 dark:text-slate-200">
        <tr>
          <th class="px-4 py-3 font-semibold" scope="col">{content.models.modelColumn}</th>
          <th class="px-4 py-3 font-semibold" scope="col">{content.models.dmiColumn}</th>
          <th class="px-4 py-3 text-center font-semibold" scope="col">{content.models.supportColumn}</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-200 bg-white dark:divide-slate-700 dark:bg-slate-900">
        {#each content.models.items as model}
          <tr>
            <th class="px-4 py-3 font-semibold text-slate-800 dark:text-slate-200" scope="row">
              Casper Excalibur {model.model}
            </th>
            <td class="px-4 py-3 font-mono text-sm text-slate-600 dark:text-slate-400">
              {model.dmiProductName || '—'}
            </td>
            <td class="px-4 py-3 text-center text-xl font-bold">
              {#if model.supported}
                <span class="text-green-600 dark:text-green-400" aria-label={content.models.supportedYes}>
                  <span aria-hidden="true">✓</span>
                  <span class="sr-only">{content.models.supportedYes}</span>
                </span>
              {:else}
                <span class="text-red-600 dark:text-red-400" aria-label={content.models.supportedNo}>
                  <span aria-hidden="true">✗</span>
                  <span class="sr-only">{content.models.supportedNo}</span>
                </span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

</section>
