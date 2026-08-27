<script lang="ts">
  let {
    title,
    body = '',
    command,
    className = 'rounded-lg border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900',
  }: {
    title?: string
    body?: string
    command: string
    className?: string
  } = $props()

  let copyState = $state<'idle' | 'copied' | 'failed'>('idle')
  let resetTimer: ReturnType<typeof setTimeout> | undefined

  function resetCopyState() {
    if (resetTimer) {
      clearTimeout(resetTimer)
    }

    resetTimer = setTimeout(() => {
      copyState = 'idle'
    }, 1800)
  }

  async function copyCommand() {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(command)
      } else {
        const textarea = document.createElement('textarea')
        textarea.value = command
        textarea.setAttribute('readonly', '')
        textarea.style.position = 'fixed'
        textarea.style.opacity = '0'
        document.body.append(textarea)
        textarea.select()
        document.execCommand('copy')
        textarea.remove()
      }

      copyState = 'copied'
    } catch {
      copyState = 'failed'
    }

    resetCopyState()
  }
</script>

<article class={className}>
  {#if title || body}
    <div>
      {#if title}
        <h3 class="mb-2 text-base font-semibold text-slate-950 dark:text-slate-50">{title}</h3>
      {/if}
      {#if body}
        <p class="mb-4 leading-relaxed text-slate-600 dark:text-slate-400">{body}</p>
      {/if}
    </div>
  {/if}

  <div class="relative">
    <button
      class="absolute top-2.5 right-2.5 min-h-7 cursor-pointer rounded-md border border-slate-300 bg-white px-2.5 py-1 text-xs font-extrabold text-slate-800 hover:border-slate-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-slate-400"
      type="button"
      aria-label={copyState === 'copied' ? 'Command copied' : 'Copy command'}
      title={copyState === 'copied' ? 'Copied' : copyState === 'failed' ? 'Copy failed' : 'Copy'}
      onclick={copyCommand}
    >
      {copyState === 'copied' ? 'Copied' : copyState === 'failed' ? 'Failed' : 'Copy'}
    </button>
    <pre class="pr-20"><code>{command}</code></pre>
  </div>
</article>
