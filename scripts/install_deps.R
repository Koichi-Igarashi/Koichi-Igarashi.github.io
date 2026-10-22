# Install the R packages needed to build the website.
#
#   Rscript scripts/install_deps.R
#
# Reproducibility: CRAN packages come from a dated snapshot of Posit Public
# Package Manager, so every machine (and GitHub Actions) gets the same,
# mutually compatible versions. babelquarto (not on CRAN) is installed from a
# fixed GitHub commit. To update everything, change the two values below,
# rebuild locally, and commit.

cran_snapshot <- "2026-10-01"
babelquarto_commit <- "3de37464a8cda6446c74a748d3b71402b408d179" # 2026-09-22, v0.1.0.9000

packages <- c(
  # rendering
  "knitr", "rmarkdown", "quarto",
  # data and tables
  "yaml", "jsonlite", "htmltools", "reactable",
  # babelquarto dependencies (installed explicitly so they also come from the snapshot)
  "brio", "cli", "fs", "purrr", "rlang", "sys", "whoami", "withr", "xml2"
)

snapshot_repo <- function(date) {
  base <- "https://packagemanager.posit.co/cran"
  if (Sys.info()[["sysname"]] == "Linux" && file.exists("/etc/os-release")) {
    os <- readLines("/etc/os-release")
    codename <- sub("^VERSION_CODENAME=", "", grep("^VERSION_CODENAME=", os, value = TRUE))
    if (length(codename) == 1 && nzchar(codename)) {
      # Linux binaries (much faster than compiling from source)
      return(sprintf("%s/__linux__/%s/%s", base, codename, date))
    }
  }
  sprintf("%s/%s", base, date)
}

repo <- snapshot_repo(cran_snapshot)
options(
  repos = c(CRAN = repo),
  # Package Manager serves Linux binaries only when it can see the R version
  HTTPUserAgent = sprintf(
    "R/%s R (%s)",
    getRversion(),
    paste(getRversion(), R.version[["platform"]], R.version[["arch"]], R.version[["os"]])
  ),
  Ncpus = max(1L, parallel::detectCores())
)

message("CRAN snapshot: ", repo)
installed <- rownames(installed.packages())
outdated <- intersect(packages, old.packages()[, "Package"])
to_install <- union(setdiff(packages, installed), outdated)
if (length(to_install) > 0) {
  install.packages(to_install)
}

babelquarto_installed <- function() {
  if (!requireNamespace("babelquarto", quietly = TRUE)) {
    return(FALSE)
  }
  identical(utils::packageDescription("babelquarto")$BuildCommit, babelquarto_commit)
}

if (!babelquarto_installed()) {
  tarball <- tempfile(fileext = ".tar.gz")
  utils::download.file(
    sprintf("https://github.com/ropensci-review-tools/babelquarto/archive/%s.tar.gz", babelquarto_commit),
    tarball,
    mode = "wb"
  )
  source_dir <- tempfile()
  utils::untar(tarball, exdir = source_dir)
  pkg_dir <- list.files(source_dir, full.names = TRUE)[1]
  # remember which commit is installed
  description <- file.path(pkg_dir, "DESCRIPTION")
  write(paste0("BuildCommit: ", babelquarto_commit), description, append = TRUE)
  install.packages(pkg_dir, repos = NULL, type = "source")
}

for (pkg in c(packages, "babelquarto")) {
  message(sprintf("%-12s %s", pkg, as.character(utils::packageVersion(pkg))))
}
