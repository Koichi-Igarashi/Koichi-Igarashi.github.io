# News, grants, awards and presentations from data/cv.yml, rendered as
# Markdown lists for the Japanese (`ja`) or English (`en`) pages.
# Use inside a chunk with `#| output: asis`.

read_cv <- function(path = "data/cv.yml") {
  yaml::read_yaml(path)
}

cv_items <- function(section, lang = c("ja", "en"), newest_first = TRUE, path = "data/cv.yml") {
  lang <- match.arg(lang)
  items <- read_cv(path)[[section]]
  if (is.null(items)) {
    stop("Section '", section, "' not found in ", path, call. = FALSE)
  }
  items <- Filter(function(item) !is.null(item[[lang]]) && nzchar(item[[lang]]), items)
  dates <- vapply(items, function(item) as.character(item$date), character(1))
  # order() keeps the file order for items with the same date
  items[order(dates, decreasing = newest_first)]
}

# style: "bullet", "numbered" or "news" (bold date followed by the text)
cv_list <- function(section, lang = c("ja", "en"), style = c("bullet", "numbered", "news"),
                    newest_first = TRUE, path = "data/cv.yml") {
  lang <- match.arg(lang)
  style <- match.arg(style)
  items <- cv_items(section, lang, newest_first, path)

  lines <- vapply(seq_along(items), function(i) {
    item <- items[[i]]
    text <- item[[lang]]
    switch(style,
      bullet = paste0("-   ", text),
      numbered = paste0(i, ".  ", text),
      news = paste0("-   **", as.character(item$date), "**: ", text)
    )
  }, character(1))

  cat(paste0(lines, collapse = "\n\n"), "\n")
}
