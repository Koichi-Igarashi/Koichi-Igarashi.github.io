# Refresh citation counts in data/citations.yml from Google Scholar.
#
#   Rscript scripts/update_citations.R
#
# Run on your own computer (Google Scholar blocks GitHub's servers), then
# commit data/citations.yml and push; the site is rebuilt with the new
# numbers. Needs R with the yaml and xml2 packages, and curl.

source("R/scholar.R")
if (!update_citations_file()) {
  stop("Could not read the Google Scholar profile; data/citations.yml was not changed.", call. = FALSE)
}
message("Updated data/citations.yml")
