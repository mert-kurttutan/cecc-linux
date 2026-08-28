export const prerender = true

const siteOrigin = 'https://cecc.mert-kurttutan.com'

export function GET() {
  return new Response(`User-agent: *
Allow: /

Sitemap: ${siteOrigin}/sitemap.xml
`, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
    },
  })
}
