# Citation counts and paper links from a Google Scholar profile.
#
# The profile page is parsed the same way as the CRAN `scholar` package
# (rows `tr.gsc_a_tr`, title `a.gsc_a_at`, citations `a.gsc_a_ac`), using
# only xml2. Google Scholar sometimes blocks automated requests; callers then
# fall back to what is saved in data/citations.yml.
#
# Google Scholar refuses requests from GitHub's servers (HTTP 403), so when
# the environment variable SERPAPI_KEY is set (a GitHub Actions secret) the
# profile is read through SerpApi's Google Scholar Author API instead.

scholar_profile_id <- "AEWO65QAAAAJ"

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || identical(x, "")) y else x

scholar_base_url <- "https://scholar.google.com"

normalise_title <- function(x) {
  x <- tolower(gsub("*", "", x, fixed = TRUE))
  x <- gsub("[[:punct:]]", " ", x)
  trimws(gsub("\\s+", " ", x))
}

curl_get <- function(url, file, timeout, headers = character()) {
  status <- suppressWarnings(system2("curl", c(
    "--silent", "--show-error", "--location", "--compressed",
    "--max-time", timeout,
    unlist(lapply(headers, function(h) c("--header", shQuote(h)))),
    "--output", shQuote(file),
    "--write-out", shQuote("%{http_code}"),
    shQuote(url)
  ), stdout = TRUE, stderr = TRUE))
  status <- paste(status, collapse = " ")
  if (status != "200") {
    stop("request failed: HTTP ", status, call. = FALSE)
  }
  invisible(file)
}

# Same result as fetch_scholar_profile(), from SerpApi (JSON)
fetch_scholar_serpapi <- function(scholar_id, api_key, timeout = 30) {
  page_url <- paste0(
    "https://serpapi.com/search.json?engine=google_scholar_author&hl=en&num=100&sort=pubdate",
    "&author_id=", utils::URLencode(scholar_id, reserved = TRUE),
    "&api_key=", utils::URLencode(api_key, reserved = TRUE)
  )
  json_file <- tempfile(fileext = ".json")
  on.exit(unlink(json_file), add = TRUE)
  tryCatch(
    curl_get(page_url, json_file, timeout),
    # never print the URL (it contains the key)
    error = function(e) stop("SerpApi ", conditionMessage(e), call. = FALSE)
  )
  data <- jsonlite::fromJSON(json_file, simplifyVector = FALSE)
  if (!is.null(data$error)) {
    stop("SerpApi: ", data$error, call. = FALSE)
  }
  articles <- data$articles
  if (length(articles) == 0) {
    stop("SerpApi returned no publications", call. = FALSE)
  }
  data.frame(
    title = vapply(articles, function(a) a$title %||% "", character(1)),
    cites = vapply(articles, function(a) as.integer(a$cited_by$value %||% 0L), integer(1)),
    url = vapply(articles, function(a) a$link %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

# data.frame(title, cites, url) for all papers on the profile; errors on failure
fetch_scholar_profile <- function(scholar_id = scholar_profile_id, timeout = 20) {
  api_key <- Sys.getenv("SERPAPI_KEY")
  if (nzchar(api_key)) {
    return(fetch_scholar_serpapi(scholar_id, api_key))
  }
  page_url <- sprintf(
    "%s/citations?hl=en&user=%s&cstart=0&pagesize=100&sortby=pubdate",
    scholar_base_url, scholar_id
  )
  # The curl command-line tool (on GitHub's runners and most systems) is
  # used so that the HTTP status is visible in the build log when blocked.
  page_file <- tempfile(fileext = ".html")
  on.exit(unlink(page_file), add = TRUE)
  curl_get(page_url, page_file, timeout, c(
    "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Accept-Language: en"
  ))
  html <- xml2::read_html(page_file, encoding = "UTF-8")
  rows <- xml2::xml_find_all(html, "//tr[contains(concat(' ', normalize-space(@class), ' '), ' gsc_a_tr ')]")
  if (length(rows) == 0) {
    stop("no publications found on the Google Scholar page (request blocked?)", call. = FALSE)
  }
  title_links <- xml2::xml_find_first(rows, ".//a[contains(@class, 'gsc_a_at')]")
  cites <- xml2::xml_text(xml2::xml_find_first(rows, ".//a[contains(@class, 'gsc_a_ac')]"))
  cites <- suppressWarnings(as.integer(gsub("[^0-9]", "", cites)))
  cites[is.na(cites)] <- 0L
  # The paper page is in `href` (older pages) or `data-href`
  href <- xml2::xml_attr(title_links, "data-href")
  plain <- xml2::xml_attr(title_links, "href")
  use_plain <- is.na(href) | href == ""
  href[use_plain] <- plain[use_plain]
  href[is.na(href) | !startsWith(href, "/citations")] <- ""
  href[href != ""] <- paste0(scholar_base_url, href[href != ""])
  data.frame(title = xml2::xml_text(title_links), cites = cites, url = href, stringsAsFactors = FALSE)
}

# list(counts = id -> citations, urls = id -> Scholar paper page) for the
# papers in data/publications.yml. Papers are matched by title (or
# `scholar_title` if the Scholar title differs).
match_scholar_profile <- function(pubs, scholar) {
  keys <- normalise_title(scholar$title)
  counts <- list()
  urls <- list()
  for (pub in pubs) {
    if (is.null(pub$id)) next
    key <- normalise_title(if (is.null(pub$scholar_title)) pub$title else pub$scholar_title)
    hit <- which(keys == key)
    if (length(hit) == 0) next
    counts[[pub$id]] <- scholar$cites[hit[1]]
    if (scholar$url[hit[1]] != "") urls[[pub$id]] <- scholar$url[hit[1]]
  }
  list(counts = counts, urls = urls)
}

# Refresh data/citations.yml from Google Scholar. Called by scripts/build.R
# before rendering, so both languages show the same numbers. When Scholar
# does not answer, the file is left as it is (the last saved values are
# shown) and the build continues. Set SKIP_SCHOLAR=true to skip the request.
update_citations_file <- function(
  publications_path = "data/publications.yml",
  citations_path = "data/citations.yml",
  scholar_id = scholar_profile_id
) {
  if (tolower(Sys.getenv("SKIP_SCHOLAR")) %in% c("1", "true", "yes")) {
    message("SKIP_SCHOLAR is set; using ", citations_path)
    return(invisible(FALSE))
  }
  pubs <- yaml::read_yaml(publications_path)$publications
  live <- tryCatch(
    match_scholar_profile(pubs, fetch_scholar_profile(scholar_id)),
    error = function(e) {
      message("Google Scholar not available (", conditionMessage(e), "); using ", citations_path)
      NULL
    }
  )
  if (is.null(live)) {
    return(invisible(FALSE))
  }
  for (pub in pubs) {
    if (!is.null(pub$id) && is.null(live$counts[[pub$id]])) {
      message("Not found on Google Scholar: ", pub$id, " (add `scholar_title` if the title differs)")
    }
  }
  message("Citation counts from Google Scholar: ", paste(names(live$counts), unlist(live$counts), sep = "=", collapse = ", "))

  # papers not (yet) on Scholar keep their saved values
  saved <- if (file.exists(citations_path)) yaml::read_yaml(citations_path) else list()
  writeLines(
    c(
      "# Citation counts and Google Scholar paper pages, keyed by publication `id`.",
      "# Refreshed from Google Scholar at every build (scripts/build.R); these saved",
      "# values are shown when Scholar does not answer. Fine to edit by hand.",
      yaml::as.yaml(list(
        source = paste0("Google Scholar (", scholar_id, ")"),
        updated = format(Sys.Date()),
        counts = utils::modifyList(saved$counts %||% list(), live$counts),
        urls = utils::modifyList(saved$urls %||% list(), live$urls)
      ))
    ),
    citations_path
  )
  invisible(TRUE)
}
