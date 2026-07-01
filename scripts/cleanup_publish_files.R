site_dir <- "_site"

if (dir.exists(site_dir)) {
  source_maps <- list.files(
    site_dir,
    pattern = "\\.map$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(source_maps) > 0) {
    unlink(source_maps)
    message("Removed ", length(source_maps), " source map file(s) from ", site_dir)
  }
}
