# Publication list for the Achievements pages (Japanese and English).
#
# All data comes from data/publications.yml (and citation counts from
# data/citations.yml), so both languages always show the same list.
# Only base R, yaml, htmltools and reactable are used.

publication_labels <- list(
  ja = list(
    year = "Year",
    item = "Publication",
    citations = "Citations",
    open_pdf = "PDFを開く",
    pdf = "PDF"
  ),
  en = list(
    year = "Year",
    item = "Publication",
    citations = "Citations",
    open_pdf = "Open PDF",
    pdf = "PDF"
  )
)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || identical(x, "")) y else x

escape_html <- function(x) {
  as.character(htmltools::htmlEscape(x, attribute = TRUE))
}

# Titles may mark scientific names with *asterisks*: *Cleantiella isopus*
format_title <- function(title) {
  gsub("\\*([^*]+)\\*", "<i>\\1</i>", escape_html(title))
}

# A link item may be a plain string or a list with `url` and `label`.
normalise_links <- function(links) {
  if (is.null(links) || length(links) == 0) {
    return(list())
  }
  if (is.character(links)) {
    links <- as.list(links)
  }
  if (!is.null(links$url)) {
    links <- list(links)
  }
  lapply(links, function(link) {
    if (is.character(link)) {
      link <- list(url = link)
    }
    list(url = link$url %||% "", label = link$label %||% "")
  })
}

is_external_url <- function(url) {
  grepl("^[a-z][a-z0-9+.-]*:", url, ignore.case = TRUE)
}

# Files stored in this repository (e.g. "papers/x.pdf") are published once,
# at the root of the Japanese site. `root_prefix` is the relative path from
# the page to that root ("../" for /achievements/, "../../" for
# /en/achievements/), so both languages link to the same file.
resolve_url <- function(url, root_prefix) {
  if (url == "" || is_external_url(url) || startsWith(url, "/")) {
    return(url)
  }
  paste0(root_prefix, url)
}

link_attributes <- function(url) {
  if (is_external_url(url)) " target='_blank' rel='noopener'" else ""
}

format_authors <- function(authors, highlight) {
  authors <- vapply(authors, escape_html, character(1))
  authors[authors == escape_html(highlight)] <- paste0("<b>", escape_html(highlight), "</b>")
  paste(authors, collapse = ", ")
}

format_venue <- function(pub) {
  volume <- as.character(pub$volume %||% "")
  issue <- as.character(pub$issue %||% "")
  pages <- as.character(pub$pages %||% pub$article %||% "")

  numbers <- volume
  if (issue != "") numbers <- paste0(numbers, "(", issue, ")")
  if (pages != "") numbers <- if (numbers == "") pages else paste0(numbers, ", ", pages)

  parts <- c(pub$journal %||% "", numbers, pub$status %||% "")
  parts <- parts[parts != ""]
  if (length(parts) == 0) {
    return("")
  }
  paste0(" <span class='publication-venue'>", escape_html(paste(parts, collapse = ", ")), ".</span>")
}

title_url <- function(pub) {
  doi <- pub$doi %||% ""
  if (doi != "") {
    return(paste0("https://doi.org/", doi))
  }
  if ((pub$url %||% "") != "") {
    return(pub$url)
  }
  paste0("https://scholar.google.com/scholar?q=", utils::URLencode(gsub("*", "", pub$title, fixed = TRUE), reserved = TRUE))
}

format_extra_links <- function(pub, root_prefix) {
  links <- character()
  doi <- pub$doi %||% ""
  if (doi != "") {
    links <- c(links, paste0(
      "<a href='https://doi.org/", escape_html(doi), "' target='_blank' rel='noopener'>DOI: ",
      escape_html(doi), "</a>"
    ))
  }

  pdfs <- normalise_links(pub$pdf)
  other_pdfs <- if (length(pdfs) > 1) pdfs[-1] else list()
  for (link in c(other_pdfs, normalise_links(pub$links))) {
    url <- resolve_url(link$url, root_prefix)
    label <- if (link$label == "") link$url else link$label
    is_pdf <- grepl("\\.pdf($|[?#])", url, ignore.case = TRUE)
    links <- c(links, paste0(
      "<a href='", escape_html(url), "'", link_attributes(url), ">",
      if (is_pdf) "PDF (" else "", escape_html(label), if (is_pdf) ")" else "",
      "</a>"
    ))
  }

  if (length(links) == 0) {
    return("")
  }
  paste0("<div class='publication-actions'>", paste(links, collapse = ""), "</div>")
}

format_pdf_icon <- function(pub, root_prefix, labels) {
  pdfs <- normalise_links(pub$pdf)
  if (length(pdfs) == 0 || pdfs[[1]]$url == "") {
    return("")
  }
  url <- resolve_url(pdfs[[1]]$url, root_prefix)
  description <- if (pdfs[[1]]$label == "") labels$open_pdf else paste0(labels$open_pdf, " (", pdfs[[1]]$label, ")")
  paste0(
    "<a class='publication-pdf-link' href='", escape_html(url), "' target='_blank' rel='noopener'",
    " aria-label='", escape_html(description), "' title='", escape_html(description), "'>",
    "<i class='bi bi-filetype-pdf' aria-hidden='true'></i>",
    "</a>"
  )
}

read_citation_counts <- function(path = "data/citations.yml") {
  if (!file.exists(path)) {
    return(list())
  }
  yaml::read_yaml(path)$counts %||% list()
}

read_publications <- function(path = "data/publications.yml") {
  yaml::read_yaml(path)
}

# Returns one row per publication, newest first.
format_publications <- function(
  lang = c("ja", "en"),
  site_root = "",
  path = "data/publications.yml",
  citations_path = "data/citations.yml"
) {
  lang <- match.arg(lang)
  labels <- publication_labels[[lang]]
  root_prefix <- site_root

  data <- read_publications(path)
  pubs <- data$publications %||% list()
  counts <- read_citation_counts(citations_path)
  highlight <- data$highlight %||% ""

  if (length(pubs) == 0) {
    return(data.frame(Year = integer(), Item = character(), Cites = character(), Pdf = character()))
  }

  years <- vapply(pubs, function(pub) as.numeric(pub$year %||% NA), numeric(1))
  order_within_year <- vapply(pubs, function(pub) as.numeric(pub$order %||% 0), numeric(1))
  pubs <- pubs[order(-years, -order_within_year, seq_along(pubs))]

  rows <- lapply(pubs, function(pub) {
    count <- if (!is.null(pub$id)) counts[[pub$id]] else NULL
    data.frame(
      Year = as.integer(pub$year),
      Item = paste0(
        "<div class='publication-item'>",
        format_authors(pub$authors, highlight), ". ",
        "<a href='", escape_html(title_url(pub)), "' target='_blank' rel='noopener'>", format_title(pub$title), "</a>.",
        format_venue(pub),
        format_extra_links(pub, root_prefix),
        "</div>"
      ),
      Cites = if (is.null(count)) "" else paste0(
        "<span class='publication-cites-label'>", labels$citations, ": </span>", count
      ),
      Pdf = format_pdf_icon(pub, root_prefix, labels),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

publication_table <- function(publications, lang = c("ja", "en")) {
  lang <- match.arg(lang)
  labels <- publication_labels[[lang]]

  reactable::reactable(
    publications,
    searchable = FALSE,
    pagination = FALSE,
    class = "publication-table",
    columns = list(
      Year = reactable::colDef(
        name = labels$year,
        maxWidth = 82,
        align = "left",
        class = "publication-cell-middle publication-year-cell",
        headerClass = "publication-year-header"
      ),
      Item = reactable::colDef(name = labels$item, html = TRUE, minWidth = 480, maxWidth = 650, class = "publication-cell-middle publication-item-cell"),
      Cites = reactable::colDef(
        name = labels$citations,
        html = TRUE,
        align = "center",
        minWidth = 95,
        maxWidth = 110,
        class = "publication-cell-center publication-cites-cell",
        headerClass = "publication-nowrap publication-cites-cell"
      ),
      Pdf = reactable::colDef(name = "", html = TRUE, align = "center", maxWidth = 64, class = "publication-cell-center publication-pdf-cell")
    ),
    style = list(fontSize = "18px")
  )
}
