# pussy-patrol

A quick joke game


## Deployment

1. In Godot, export the **Web** preset to `exports/html/game.html`
2. Run:

```
./scripts/publish-pages.sh
```

That copies the export into `docs/`, sets `index.html`, applies `art/web/icon.png` (favicon/PWA) and `art/web/social.png` (splash / `og:image`), and preserves `CNAME`.
