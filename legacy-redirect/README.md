# Redirects for the old Quarto Pub site

Instant meta-refresh + canonical pages that send every URL of
<https://igapipy.quarto.pub/koichi-igarashi/> to the new site
(`new-site-url` in `_quarto.yml`). Quarto Pub cannot send HTTP 301.

Publish before 2026-12-31 (when Quarto Pub publishing ends), only after the new site is live:

```sh
cd legacy-redirect
quarto publish quarto-pub     # uses the existing site ID in _publish.yml
bash check_redirects.sh       # verify
```

Do not run `quarto publish quarto-pub` from the repository root.
