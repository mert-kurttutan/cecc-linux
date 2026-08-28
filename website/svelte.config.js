import adapter from '@sveltejs/adapter-static'
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

/** @type {import("@sveltejs/kit").Config} */
export default {
  preprocess: vitePreprocess(),
  kit: {
    files: {
      assets: 'public',
    },
    adapter: adapter({
      pages: 'dist',
      assets: 'dist',
    }),
  },
}
