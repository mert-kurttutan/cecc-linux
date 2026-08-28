import { routePaths } from '../../content'

export const prerender = true

const siteOrigin = 'https://cecc.mert-kurttutan.com'

function escapeXml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

export function GET() {
  const urls = Object.values(routePaths).flatMap((paths) => Object.values(paths))
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((path) => `  <url><loc>${escapeXml(`${siteOrigin}${path}`)}</loc></url>`).join('\n')}
</urlset>
`

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
    },
  })
}
