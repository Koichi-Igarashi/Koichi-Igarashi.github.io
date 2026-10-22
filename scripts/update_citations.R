# Refresh citation counts in data/citations.yml from Google Scholar.
#
#   Rscript scripts/update_citations.R
#
# The website build does this automatically (scripts/build.R); run this by
# hand to save the latest numbers in the repository.

source("R/scholar.R")
if (!update_citations_file()) {
  stop("Could not read the Google Scholar profile; data/citations.yml was not changed.", call. = FALSE)
}
message("Updated data/citations.yml")
