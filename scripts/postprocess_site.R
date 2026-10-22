# Post-processing of the rendered bilingual site (run by scripts/build.R
# after babelquarto::render_website()).
#
# For every HTML page in _site/ it
#   - adds <link rel="canonical"> and og:url / og:locale,
#   - replaces babelquarto's hreflang links (which point to non-existent
#     `*.en.html` files on websites) with correct ja / en / x-default links,
#     only when the translated page really exists,
#   - replaces babelquarto's language drop-down with a one-click
#     "English" / "日本語" link that opens the same page in the other
#     language (or the other language's home page if there is no
#     translation),
#   - adds Schema.org Person data (JSON-LD) to the two home pages,
#   - marks the 404 page as noindex.
# It then rewrites sitemap.xml with the canonical URLs and writes robots.txt.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || identical(x, "")) y else x

main_language <- "ja"
other_language <- "en"

language_names <- c(ja = "日本語", en = "English")
og_locales <- c(ja = "ja_JP", en = "en_US")

page_language <- function(rel_path) {
  if (startsWith(rel_path, paste0(other_language, "/"))) other_language else main_language
}

# "en/about.html" <-> "about.html"
counterpart_path <- function(rel_path) {
  if (page_language(rel_path) == other_language) {
    sub(paste0("^", other_language, "/"), "", rel_path)
  } else {
    paste0(other_language, "/", rel_path)
  }
}

home_path <- function(lang) {
  if (lang == main_language) "index.html" else paste0(other_language, "/index.html")
}

# Canonical form drops a trailing "index.html": https://example.org/en/
public_url <- function(site_url, rel_path) {
  rel_path <- sub("(^|/)index\\.html$", "\\1", rel_path)
  paste0(site_url, "/", rel_path)
}

# "/website/" for https://user.github.io/website. On the 404 page Quarto
# already wrote absolute links (e.g. "/website/styles.css"); reuse that prefix.
absolute_prefix <- function(html, site_url) {
  css <- xml2::xml_attr(xml2::xml_find_first(html, "//link[@rel='stylesheet' and substring(@href, string-length(@href) - 9) = 'styles.css']"), "href")
  if (!is.na(css) && startsWith(css, "/")) {
    return(sub("styles\\.css$", "", css))
  }
  paste0(sub("/$", "", sub("^https?://[^/]+", "", site_url)), "/")
}

relative_href <- function(from, to) {
  depth <- lengths(regmatches(from, gregexpr("/", from)))
  paste0(strrep("../", depth), to)
}

is_redirect_page <- function(html) {
  length(xml2::xml_find_all(html, "//meta[translate(@http-equiv, 'REFRESH', 'refresh')='refresh']")) > 0
}

add_head_node <- function(head, tag, attrs) {
  node <- xml2::xml_add_child(head, tag)
  for (name in names(attrs)) {
    xml2::xml_set_attr(node, name, attrs[[name]])
  }
  invisible(node)
}

remove_nodes <- function(html, xpath) {
  xml2::xml_remove(xml2::xml_find_all(html, xpath))
}

person_json_ld <- function(profile, lang, site_url, page_url) {
  pick <- function(field) profile[[field]][[lang]] %||% profile[[field]][["en"]]
  other <- if (lang == "ja") "en" else "ja"
  data <- list(
    "@context" = "https://schema.org",
    "@type" = "Person",
    "@id" = paste0(site_url, "/#person"),
    name = pick("name"),
    alternateName = profile$name[[other]],
    url = page_url,
    image = paste0(site_url, "/images/og-image.jpg"),
    jobTitle = pick("job_title"),
    affiliation = list(
      "@type" = "CollegeOrUniversity",
      name = pick("affiliation"),
      parentOrganization = list(
        "@type" = "CollegeOrUniversity",
        name = pick("university"),
        url = profile$university_url
      )
    ),
    knowsAbout = as.list(profile$knows_about[[lang]] %||% profile$knows_about$en),
    sameAs = as.list(profile$same_as)
  )
  json <- jsonlite::toJSON(data, auto_unbox = TRUE, pretty = TRUE)
  # never allow "</script>" inside the JSON block
  gsub("</", "<\\/", json, fixed = TRUE)
}

language_switch_item <- function(html, rel_path, site_root, site_url) {
  lang <- page_language(rel_path)
  target_lang <- if (lang == main_language) other_language else main_language
  target <- counterpart_path(rel_path)
  has_translation <- file.exists(file.path(site_root, target))
  if (!has_translation) {
    target <- home_path(target_lang)
  }

  navbar <- xml2::xml_find_first(html, "//div[@id='navbarCollapse']")
  if (inherits(navbar, "xml_missing")) {
    return(invisible())
  }

  # babelquarto's drop-down (we keep our own one-click link instead)
  remove_nodes(html, "//li[.//*[@id='languages-links-parent']]")
  remove_nodes(html, "//*[@id='languages-links-parent']")
  remove_nodes(html, "//ul[@id='language-switch-nav']")

  quarto_tools <- xml2::xml_find_first(navbar, "./div[contains(@class, 'quarto-navbar-tools')]")
  ul <- if (inherits(quarto_tools, "xml_missing")) {
    xml2::xml_add_child(navbar, "ul")
  } else {
    xml2::xml_add_sibling(quarto_tools, "ul", .where = "before")
  }
  xml2::xml_set_attrs(ul, c(class = "navbar-nav navbar-nav-scroll ms-auto", id = "language-switch-nav"))
  li <- xml2::xml_add_child(ul, "li", class = "nav-item")
  title <- if (has_translation) {
    if (target_lang == "en") "Read this page in English" else "このページを日本語で読む"
  } else {
    if (target_lang == "en") "English version (home)" else "日本語版（ホーム）"
  }
  a <- xml2::xml_add_child(
    li, "a",
    class = "nav-link language-switch",
    id = "language-switch",
    # the 404 page is served at arbitrary URLs, so it needs an absolute path
    # (same prefix that Quarto used for the page's own links)
    href = if (rel_path == "404.html") paste0(absolute_prefix(html, site_url), target) else relative_href(rel_path, target),
    hreflang = target_lang,
    lang = target_lang,
    title = title
  )
  xml2::xml_add_child(a, "i", class = "bi bi-globe2", `aria-hidden` = "true")
  span <- xml2::xml_add_child(a, "span", class = "menu-text")
  xml2::xml_text(span) <- paste0(" ", language_names[[target_lang]])
  invisible()
}

process_page <- function(path, site_root, site_url, profile) {
  rel_path <- sub("^/", "", sub(normalizePath(site_root), "", normalizePath(path), fixed = TRUE))
  html <- xml2::read_html(path, encoding = "UTF-8")
  head <- xml2::xml_find_first(html, "//head")
  lang <- page_language(rel_path)
  redirect <- is_redirect_page(html)
  not_found <- rel_path == "404.html"

  remove_nodes(head, ".//link[@rel='alternate' and @hreflang]")
  remove_nodes(head, ".//link[@rel='canonical']")
  remove_nodes(head, ".//meta[@property='og:url' or @property='og:locale' or @property='og:locale:alternate']")
  remove_nodes(head, ".//script[@id='person-json-ld']")

  page_url <- public_url(site_url, rel_path)
  translation <- counterpart_path(rel_path)
  has_translation <- !redirect && !not_found && file.exists(file.path(site_root, translation))

  if (not_found) {
    remove_nodes(head, ".//meta[@name='robots']")
    add_head_node(head, "meta", list(name = "robots", content = "noindex"))
  } else if (!redirect) {
    add_head_node(head, "link", list(rel = "canonical", href = page_url))
    add_head_node(head, "meta", list(property = "og:url", content = page_url))
    add_head_node(head, "meta", list(property = "og:locale", content = og_locales[[lang]]))
    if (has_translation) {
      other <- page_language(translation)
      add_head_node(head, "meta", list(property = "og:locale:alternate", content = og_locales[[other]]))
      urls <- list()
      urls[[lang]] <- page_url
      urls[[other]] <- public_url(site_url, translation)
      for (code in c(main_language, other_language)) {
        add_head_node(head, "link", list(rel = "alternate", hreflang = code, href = urls[[code]]))
      }
      add_head_node(head, "link", list(rel = "alternate", hreflang = "x-default", href = urls[[main_language]]))
    }
  }

  if (rel_path %in% c(home_path(main_language), home_path(other_language)) && !is.null(profile)) {
    script <- xml2::xml_add_child(head, "script", type = "application/ld+json", id = "person-json-ld")
    xml2::xml_text(script) <- person_json_ld(profile, lang, site_url, page_url)
  }

  language_switch_item(html, rel_path, site_root, site_url)

  xml2::write_html(html, path, options = "no_declaration")

  list(
    path = rel_path,
    url = page_url,
    indexable = !redirect && !not_found
  )
}

write_sitemap <- function(pages, site_root, lastmod) {
  pages <- Filter(function(page) page$indexable, pages)
  urls <- vapply(pages, function(page) page$url, character(1))
  # main language first, then English; stable alphabetical order inside
  is_other <- vapply(pages, function(page) page_language(page$path) == other_language, logical(1))
  urls <- urls[order(is_other, urls)]
  entries <- vapply(urls, function(url) {
    mod <- lastmod[[url]] %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    paste0("  <url>\n    <loc>", url, "</loc>\n    <lastmod>", mod, "</lastmod>\n  </url>")
  }, character(1))
  writeLines(
    c(
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
      entries,
      "</urlset>"
    ),
    file.path(site_root, "sitemap.xml"),
    useBytes = TRUE
  )
}

# lastmod values that Quarto wrote, keyed by canonical URL
read_sitemap_lastmod <- function(site_root, site_url) {
  path <- file.path(site_root, "sitemap.xml")
  if (!file.exists(path)) {
    return(list())
  }
  doc <- xml2::read_xml(path)
  ns <- xml2::xml_ns_rename(xml2::xml_ns(doc), d1 = "s")
  entries <- xml2::xml_find_all(doc, "//s:url", ns)
  result <- list()
  for (entry in entries) {
    loc <- xml2::xml_text(xml2::xml_find_first(entry, "s:loc", ns))
    mod <- xml2::xml_text(xml2::xml_find_first(entry, "s:lastmod", ns))
    rel <- sub(paste0("^", site_url, "/?"), "", loc)
    result[[public_url(site_url, rel)]] <- mod
  }
  result
}

postprocess_site <- function(site_root = "_site", site_url, profile_path = "data/profile.yml") {
  site_url <- sub("/$", "", site_url)
  profile <- if (file.exists(profile_path)) yaml::read_yaml(profile_path) else NULL

  files <- list.files(site_root, pattern = "\\.html$", recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("(^|/)site_libs/", files)]

  lastmod <- read_sitemap_lastmod(site_root, site_url)
  pages <- lapply(files, process_page, site_root = site_root, site_url = site_url, profile = profile)
  write_sitemap(pages, site_root, lastmod)

  unlink(file.path(site_root, other_language, c("robots.txt", "sitemap.xml")))
  writeLines(
    c(
      "User-agent: *",
      "Allow: /",
      "",
      paste0("Sitemap: ", site_url, "/sitemap.xml")
    ),
    file.path(site_root, "robots.txt")
  )

  message("Post-processed ", length(pages), " HTML page(s) in ", site_root)
  invisible(pages)
}
