make_pdf_preview <- function(pdf, output = NULL, page = 1, dpi = 220) {
  pdftoppm <- Sys.which("pdftoppm")
  if (pdftoppm == "") {
    stop(
      "pdftoppm was not found. Install Poppler first, for example: brew install poppler",
      call. = FALSE
    )
  }

  if (!file.exists(pdf)) {
    stop("PDF file was not found: ", pdf, call. = FALSE)
  }

  if (is.null(output)) {
    output <- sub("\\.pdf$", "-preview", pdf, ignore.case = TRUE)
    if (identical(output, pdf)) {
      output <- paste0(pdf, "-preview")
    }
  } else {
    output <- sub("\\.png$", "", output, ignore.case = TRUE)
  }

  output_dir <- dirname(output)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  status <- system2(
    pdftoppm,
    args = c(
      "-png",
      "-singlefile",
      "-f", as.character(page),
      "-r", as.character(dpi),
      shQuote(pdf),
      shQuote(output)
    )
  )

  if (status != 0) {
    stop("pdftoppm failed with exit status ", status, call. = FALSE)
  }

  preview <- paste0(output, ".png")
  message("Created: ", preview)
  invisible(preview)
}

# Usage from the RStudio Console:
# source("scripts/make_pdf_preview.R")
# make_pdf_preview("papers/tonic-immobility.pdf")
#
# This creates:
# papers/tonic-immobility-preview.png
#
# Then add both paths to data/publications_manual.yml or data/publications_metadata.yml:
# pdf: "papers/tonic-immobility.pdf"
# pdf_preview: "papers/tonic-immobility-preview.png"
# Example:
# make_pdf_preview("papers/JMBA_Igarashi_2024.pdf")
