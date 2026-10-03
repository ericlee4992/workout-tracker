/** Placeholder privacy and support pages; ticket 08 writes their real text with the user. */
function page(title: string, body: string): Response {
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${title} — Stacked</title>
<style>body{font:17px/1.5 -apple-system,system-ui,sans-serif;max-width:40rem;margin:2rem auto;padding:0 1rem;color:#0b0c0e;background:#f2f3f5}
@media (prefers-color-scheme:dark){body{color:#f4f6f8;background:#060708}}</style></head>
<body><h1>${title}</h1>${body}</body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}

export function privacyPage(): Response {
  return page("Privacy", "<p>Stacked is in a private beta. This policy is being written and will be published here before anyone outside the developer's team is invited.</p>");
}

export function supportPage(): Response {
  return page("Support", "<p>Stacked is in a private beta. Send feedback from inside the app (Settings) or through TestFlight.</p>");
}
