<script lang="ts">
  let {
    title,
    body = '',
    command,
    className = 'command-card',
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
        <h3>{title}</h3>
      {/if}
      {#if body}
        <p>{body}</p>
      {/if}
    </div>
  {/if}

  <div class="command-block">
    <button
      class="copy-button"
      type="button"
      aria-label={copyState === 'copied' ? 'Command copied' : 'Copy command'}
      title={copyState === 'copied' ? 'Copied' : copyState === 'failed' ? 'Copy failed' : 'Copy'}
      onclick={copyCommand}
    >
      {copyState === 'copied' ? 'Copied' : copyState === 'failed' ? 'Failed' : 'Copy'}
    </button>
    <pre><code>{command}</code></pre>
  </div>
</article>
