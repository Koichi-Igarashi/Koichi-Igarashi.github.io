empty_publications <- function() {
  tibble(Year = integer(), Item = character(), Cites = character(), Pdf = character(), Sort = numeric())
}

publication_key <- function(title) {
  title %>%
    str_to_lower() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish()
}

read_publication_metadata <- function(path = "data/publications_metadata.yml") {
  if (!file.exists(path)) {
    return(tibble(.publication_key = character()))
  }

  metadata <- yaml::read_yaml(path)
  if (length(metadata) == 0) {
    return(tibble(.publication_key = character()))
  }

  metadata %>%
    bind_rows() %>%
    mutate(
      title = coalesce(title, ""),
      .publication_key = publication_key(title)
    ) %>%
    select(-title)
}

merge_publication_metadata <- function(publications, metadata_path = "data/publications_metadata.yml") {
  metadata <- read_publication_metadata(metadata_path)
  if (nrow(metadata) == 0) {
    return(publications)
  }

  optional_fields <- c("number", "volume", "issue", "pages", "status", "link", "pdf", "pdf_url", "pdf_preview")
  missing_fields <- setdiff(optional_fields, names(publications))
  publications[missing_fields] <- NA_character_

  publications %>%
    mutate(.publication_key = publication_key(title)) %>%
    mutate(across(any_of(optional_fields), ~ na_if(as.character(.x), ""))) %>%
    rows_patch(metadata, by = ".publication_key", unmatched = "ignore") %>%
    select(-.publication_key)
}

coalesce_field <- function(data, field, default = "") {
  if (field %in% names(data)) {
    coalesce(as.character(data[[field]]), default)
  } else {
    rep(default, nrow(data))
  }
}

format_issue_text <- function(data) {
  number <- coalesce_field(data, "number")
  volume <- coalesce_field(data, "volume")
  issue <- coalesce_field(data, "issue")
  pages <- coalesce_field(data, "pages")

  structured_number <- case_when(
    volume != "" & issue != "" & pages != "" ~ paste0(volume, "(", issue, "), ", pages),
    volume != "" & issue != "" ~ paste0(volume, "(", issue, ")"),
    volume != "" & pages != "" ~ paste0(volume, ", ", pages),
    pages != "" ~ pages,
    TRUE ~ ""
  )

  if_else(number != "", number, structured_number)
}

format_publication_details <- function(journal, issue_text, status) {
  detail <- case_when(
    journal != "" & issue_text != "" ~ paste0(journal, ", ", issue_text),
    journal != "" ~ journal,
    TRUE ~ issue_text
  )

  paste0(
    case_when(
      detail != "" & status != "" ~ paste0(" <span class='publication-venue'>", detail, ", ", status, ".</span>"),
      detail != "" ~ paste0(" <span class='publication-venue'>", detail, ".</span>"),
      status != "" ~ paste0(" <span class='publication-venue'>", status, ".</span>"),
      TRUE ~ ""
    )
  )
}

format_publication_assets <- function(pdf_url, pdf_preview) {
  has_pdf <- pdf_url != ""

  paste0(
    if_else(
      has_pdf & pdf_preview != "",
      paste0(
        "<a class='publication-pdf-card' href='", pdf_url, "' download>",
        "<img src='", pdf_preview, "' alt='PDF preview'>",
        "<span class='publication-pdf-icon' aria-hidden='true'><i class='bi bi-download'></i></span>",
        "</a>"
      ),
      if_else(
        has_pdf,
        paste0(
          "<div class='publication-actions'>",
          "<a class='publication-download' href='", pdf_url, "' download>Download PDF</a>",
          "</div>"
        ),
        ""
      )
    )
  )
}

format_publication_embed <- function(pdf_url) {
  has_pdf <- pdf_url != ""

  paste0(
    if_else(
      has_pdf,
      paste0(
        "<details class='publication-preview'>",
        "<summary>PDF preview</summary>",
        "<iframe src='", pdf_url, "' loading='lazy' title='PDF preview'></iframe>",
        "</details>"
      ),
      ""
    )
  )
}

format_scholar_records <- function(publications, metadata_path = "data/publications_metadata.yml") {
  publications %>%
    bind_rows() %>%
    filter(!(journal %in% c("EcoEvoRxiv", "bioRxiv", ""))) %>%
    merge_publication_metadata(metadata_path) %>%
    arrange(desc(year)) %>%
    mutate(
      title = coalesce(title, ""),
      journal = coalesce(journal, ""),
      status = coalesce_field(., "status"),
      pdf_url = coalesce_field(., "pdf_url"),
      pdf_url = if_else(pdf_url == "", coalesce_field(., "pdf"), pdf_url),
      pdf_preview = coalesce_field(., "pdf_preview"),
      issue_text = format_issue_text(.),
      author = str_to_title(author),
      author = author %>%
        str_split(", ") %>%
        map_chr(~ paste0(
          ifelse(.x == "K Igarashi", paste0("<b>", .x, "</b>"), .x),
          collapse = ", "
        )),
      title = str_to_sentence(title),
      journal = journal %>%
        str_to_title() %>%
        str_replace_all("Of", "of") %>%
        str_replace_all("The", "the") %>%
        str_replace_all("And", "and"),
      link = paste0("https://scholar.google.com/scholar?q=", URLencode(title)),
      details = format_publication_details(journal, issue_text, status),
      assets = format_publication_assets(pdf_url, pdf_preview)
    ) %>%
    transmute(
      Year = year,
      Item = paste0(
        "<div class='publication-item'>",
        author, ". <a href='", link, "' target='_blank'>", title, "</a>.",
        details,
        "</div>"
      ),
      Cites = as.character(cites),
      Pdf = assets,
      Sort = year
    )
}

format_scholar_publications <- function(
  scholar_id,
  cache_path = "data/publications_scholar.yml",
  metadata_path = "data/publications_metadata.yml"
) {
  publications <- tryCatch(
    get_publications(scholar_id),
    error = function(error) {
      if (!file.exists(cache_path)) {
        stop(error)
      }

      warning(
        "Could not fetch Google Scholar publications; using cached publication data from ",
        cache_path,
        call. = FALSE
      )
      yaml::read_yaml(cache_path)
    }
  )

  format_scholar_records(publications, metadata_path)
}

format_manual_publications <- function(path = "data/publications_manual.yml") {
  if (!file.exists(path)) {
    return(empty_publications())
  }

  publications <- yaml::read_yaml(path)
  if (length(publications) == 0) {
    return(empty_publications())
  }

  publications %>%
    bind_rows() %>%
    mutate(
      link = coalesce_field(., "link"),
      journal = coalesce_field(., "journal"),
      status = coalesce_field(., "status"),
      pdf_url = coalesce_field(., "pdf_url"),
      pdf_url = if_else(pdf_url == "", coalesce_field(., "pdf"), pdf_url),
      pdf_preview = coalesce_field(., "pdf_preview"),
      issue_text = format_issue_text(.),
      title_text = if_else(
        link == "",
        title,
        paste0("<a href='", link, "' target='_blank'>", title, "</a>")
      ),
      details = format_publication_details(journal, issue_text, status),
      assets = format_publication_assets(pdf_url, pdf_preview),
      Sort = as.numeric(year) + 0.5
    ) %>%
    transmute(
      Year = year,
      Item = paste0(
        "<div class='publication-item'>",
        author, ". ", title_text, ".",
        details,
        "</div>"
      ),
      Cites = "",
      Pdf = assets,
      Sort = Sort
    )
}

format_publications <- function(
  scholar_id,
  manual_path = "data/publications_manual.yml",
  scholar_cache_path = "data/publications_scholar.yml",
  metadata_path = "data/publications_metadata.yml"
) {
  bind_rows(
    format_manual_publications(manual_path),
    format_scholar_publications(scholar_id, scholar_cache_path, metadata_path)
  ) %>%
    arrange(desc(Sort)) %>%
    select(-Sort)
}

publication_table <- function(publications) {
  publications %>%
    reactable(
      searchable = FALSE,
      pagination = FALSE,
      columns = list(
        Year = colDef(
          maxWidth = 82,
          align = "left",
          class = "publication-cell-middle publication-year-cell",
          headerClass = "publication-year-header"
        ),
        Item = colDef(html = TRUE, minWidth = 480, maxWidth = 650, class = "publication-cell-middle"),
        Cites = colDef(
          name = "Citations",
          align = "center",
          minWidth = 95,
          maxWidth = 110,
          class = "publication-cell-center",
          headerClass = "publication-nowrap"
        ),
        Pdf = colDef(name = "", html = TRUE, align = "center", maxWidth = 90, class = "publication-cell-center")
      ),
      style = list(fontSize = "18px")
    )
}
