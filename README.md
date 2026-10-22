# koichi-igarashi.github.io

Source of <https://koichi-igarashi.github.io/> (Japanese, with English at `/en/`).
Built with Quarto and babelquarto; deployed to GitHub Pages by `.github/workflows/publish.yml` on push to `main`.

## Update

- News, grants, awards, presentations: `data/cv.yml`
- Publications: `data/publications.yml` (PDFs in `papers/` or external URLs); citation counts are fetched from Google Scholar at every build (weekly rebuild) via SerpApi (repository secret `SERPAPI_KEY`, because Scholar blocks GitHub's servers), with the last saved values in `data/citations.yml`
- Pages: `index.qmd`, `achievements/index.qmd` (English: `*.en.qmd`); menus: `_quarto-ja.yml`, `_quarto-en.yml`

## Build locally

```sh
Rscript scripts/install_deps.R          # once
Rscript scripts/build.R --local && Rscript scripts/check_site.R --local
python3 -m http.server 4321 -d _site    # http://localhost:4321/
```

Requires Quarto 1.10.19 and R (4.6.1 in CI). Old Quarto Pub redirects: `legacy-redirect/`.
