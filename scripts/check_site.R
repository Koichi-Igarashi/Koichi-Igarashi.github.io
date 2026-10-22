# Checks for the generated site in _site/ (run after scripts/build.R; also
# run by GitHub Actions). Exits with an error if anything is broken.
#
#   Rscript scripts/check_site.R           # after Rscript scripts/build.R
#   Rscript scripts/check_site.R --local   # after Rscript scripts/build.R --local

site_root <- "_site"
config <- yaml::read_yaml("_quarto.yml")
site_url <- sub("/$", "", Sys.getenv("BABELQUARTO_CI_URL", config$website$`site-url`))
if ("--local" %in% commandArgs(trailingOnly = TRUE)) site_url <- "http://localhost:4321"
# Quarto writes absolute paths on the 404 page using site-url from
# _quarto.yml: "/website/" for https://user.github.io/website
site_path <- paste0(sub("/$", "", sub("^https?://[^/]+", "", config$website$`site-url`)), "/")

problems <- character()
problem <- function(...) problems <<- c(problems, paste0(...))

expected_pages <- c(
  "index.html", "about.html", "achievements.html", "posts.html", "404.html",
  "english.html", "posts/test/index.html",
  "en/index.html", "en/about.html", "en/achievements.html", "en/posts.html"
)
for (page in expected_pages) {
  if (!file.exists(file.path(site_root, page))) problem("missing page: ", page)
}

# public URL -> file in _site
url_to_file <- function(url) {
  rel <- sub(paste0("^", site_url, "/?"), "", url)
  if (rel == "" || endsWith(rel, "/")) rel <- paste0(rel, "index.html")
  file.path(site_root, rel)
}

resolve_relative <- function(page, href) {
  href <- sub("[?#].*$", "", href)
  if (href == "") {
    return(NA_character_)
  }
  target <- file.path(dirname(file.path(site_root, page)), utils::URLdecode(href))
  if (dir.exists(target)) target <- file.path(target, "index.html")
  target
}

is_skipped_link <- function(href) {
  grepl("^(https?:|mailto:|tel:|javascript:|data:|#|//)", href) || href == ""
}

pages <- list.files(site_root, pattern = "\\.html$", recursive = TRUE)
pages <- pages[!grepl("^site_libs/", pages)]

for (page in pages) {
  html <- xml2::read_html(file.path(site_root, page), encoding = "UTF-8")
  redirect <- length(xml2::xml_find_all(html, "//meta[@http-equiv='refresh']")) > 0
  lang <- xml2::xml_attr(xml2::xml_find_first(html, "//html"), "lang")
  expected_lang <- if (startsWith(page, "en/")) "en" else "ja"
  if (!identical(lang, expected_lang)) problem(page, ": <html lang> is ", lang, ", expected ", expected_lang)

  title <- xml2::xml_text(xml2::xml_find_first(html, "//title"))
  if (is.na(title) || !nzchar(title)) problem(page, ": empty <title>")

  canonical <- xml2::xml_attr(xml2::xml_find_all(html, "//link[@rel='canonical']"), "href")
  if (!redirect && page != "404.html") {
    if (length(canonical) != 1) {
      problem(page, ": expected 1 canonical link, found ", length(canonical))
    } else {
      if (!startsWith(canonical, paste0(site_url, "/"))) problem(page, ": canonical not under site-url: ", canonical)
      if (!file.exists(url_to_file(canonical))) problem(page, ": canonical target missing: ", canonical)
    }
    description <- xml2::xml_attr(xml2::xml_find_first(html, "//meta[@name='description']"), "content")
    if (is.na(description) && !startsWith(page, "posts/")) problem(page, ": no meta description")
  }

  alternates <- xml2::xml_find_all(html, "//link[@rel='alternate' and @hreflang]")
  if (length(alternates) > 0) {
    langs <- sort(xml2::xml_attr(alternates, "hreflang"))
    if (!identical(langs, sort(c("en", "ja", "x-default")))) problem(page, ": hreflang set is ", paste(langs, collapse = ","))
    for (href in xml2::xml_attr(alternates, "href")) {
      if (!file.exists(url_to_file(href))) problem(page, ": hreflang target missing: ", href)
    }
  }

  if (length(xml2::xml_find_all(html, "//*[@id='languages-links-parent']")) > 0) {
    problem(page, ": babelquarto language drop-down was not replaced")
  }
  switch_link <- xml2::xml_find_all(html, "//a[@id='language-switch']")
  if (length(switch_link) != 1) {
    problem(page, ": expected 1 language switch link, found ", length(switch_link))
  }

  # internal links, images, scripts and stylesheets
  refs <- c(
    xml2::xml_attr(xml2::xml_find_all(html, "//a[@href]"), "href"),
    xml2::xml_attr(xml2::xml_find_all(html, "//img[@src]"), "src"),
    xml2::xml_attr(xml2::xml_find_all(html, "//script[@src]"), "src"),
    xml2::xml_attr(xml2::xml_find_all(html, "//link[@rel='stylesheet' and @href]"), "href")
  )
  for (href in unique(refs)) {
    if (is_skipped_link(href)) next
    if (startsWith(href, "/")) {
      # only the 404 page may use absolute paths (it is served at any URL)
      if (page != "404.html" || !startsWith(href, site_path)) {
        problem(page, ": root-relative link breaks under a sub-path: ", href)
      } else if (!file.exists(file.path(site_root, substring(sub("[?#].*$", "", href), nchar(site_path) + 1)))) {
        problem(page, ": broken link/resource: ", href)
      }
      next
    }
    target <- resolve_relative(page, href)
    if (!is.na(target) && !file.exists(target)) problem(page, ": broken link/resource: ", href)
  }
  # absolute links to this site
  for (href in refs[startsWith(refs, paste0(site_url, "/"))]) {
    if (!file.exists(url_to_file(sub("[?#].*$", "", href)))) problem(page, ": broken absolute link: ", href)
  }

  json_ld <- xml2::xml_find_all(html, "//script[@type='application/ld+json']")
  for (node in json_ld) {
    ok <- tryCatch({ jsonlite::fromJSON(xml2::xml_text(node)); TRUE }, error = function(e) FALSE)
    if (!ok) problem(page, ": invalid JSON-LD")
  }
  if (page %in% c("index.html", "en/index.html") && length(json_ld) == 0) problem(page, ": no JSON-LD")
}

# sitemap.xml
sitemap_path <- file.path(site_root, "sitemap.xml")
if (!file.exists(sitemap_path)) {
  problem("sitemap.xml missing")
} else {
  doc <- xml2::read_xml(sitemap_path)
  locs <- xml2::xml_text(xml2::xml_find_all(doc, "//*[local-name()='loc']"))
  for (loc in locs) if (!file.exists(url_to_file(loc))) problem("sitemap: missing target ", loc)
  if (!any(grepl("/en/", locs))) problem("sitemap: no English pages")
  if (any(grepl("english\\.html|404\\.html", locs))) problem("sitemap: contains redirect/404 pages")
  if (anyDuplicated(locs)) problem("sitemap: duplicate URLs")
}

robots <- file.path(site_root, "robots.txt")
if (!file.exists(robots) || !any(grepl(paste0("Sitemap: ", site_url, "/sitemap.xml"), readLines(robots), fixed = TRUE))) {
  problem("robots.txt missing or without Sitemap line")
}

# PDFs stored in the repository must be published
pubs <- yaml::read_yaml("data/publications.yml")$publications
for (pub in pubs) {
  for (pdf in pub$pdf) {
    url <- if (is.list(pdf)) pdf$url else pdf
    if (!grepl("^[a-z]+:", url) && !file.exists(file.path(site_root, url))) problem("PDF not published: ", url)
  }
}

if (length(problems) > 0) {
  message(paste0("✗ ", problems, collapse = "\n"))
  stop(length(problems), " problem(s) found in ", site_root, call. = FALSE)
}
message("✓ ", length(pages), " pages checked: titles, canonical, hreflang, language switch, links, sitemap, robots.txt, PDFs")
