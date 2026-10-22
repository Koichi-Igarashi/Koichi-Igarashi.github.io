# Build the bilingual website into _site/.
#
#   Rscript scripts/build.R           # production build (URLs from _quarto.yml)
#   Rscript scripts/build.R --local   # build for local preview (see README.md)
#
# Steps: citation counts are refreshed from Google Scholar (R/scholar.R),
# babelquarto renders the Japanese site (root) and the English site
# (en/), then scripts/postprocess_site.R adds canonical / hreflang / sitemap /
# robots.txt and the language switch.

args <- commandArgs(trailingOnly = TRUE)
local_preview <- "--local" %in% args

config <- yaml::read_yaml("_quarto.yml")
site_url <- Sys.getenv("BABELQUARTO_CI_URL", config$website$`site-url`)
site_url <- sub("/$", "", site_url)

# For local preview, links that babelquarto writes are root-relative so the
# site can be served from http://localhost:PORT/ .
render_url <- if (local_preview) "" else site_url

# Latest citation counts from Google Scholar (keeps the saved ones if blocked)
source("R/scholar.R")
update_citations_file()

options(babelquarto.quiet = TRUE)
babelquarto::render_website(".", site_url = render_url, preview = FALSE)

source("scripts/postprocess_site.R")
postprocess_site("_site", site_url = if (local_preview) "http://localhost:4321" else site_url)

if (local_preview) {
  message("\nPreview: python3 -m http.server 4321 -d _site  ->  http://localhost:4321/")
}
