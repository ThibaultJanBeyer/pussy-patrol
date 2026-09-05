# pussy-patrol

A quick joke game


## Deployment

1. In Godot, export the **Web** preset to `exports/html/game.html`
2. Run:

```
./scripts/publish-pages.sh
```

That copies the export into `docs/`, sets `index.html`, applies `art/web/icon.png` (favicon/PWA) and `art/web/social.png` (splash / `og:image`), and preserves `CNAME`.

PWA/service worker is **off** (threads are off, so it only slowed downloads). After deploying, hard-refresh once or unregister the old service worker for `pussy-patrol.com` in DevTools → Application → Service Workers.
