#!/usr/bin/env Rscript
# Install minimal dependencies for Paper C standalone repo.
# Usage:
#   Rscript scripts/00_install_deps.R
pkgs <- c(
  "data.table","survival","future","future.apply",
  "ggplot2","glmnet"
)
# Optional (only needed if you enable TMLE):
opt <- c("tmle","SuperLearner")

# Optional (Patterns-style artifacts):
# The code base does not require rmarkdown to run, but it can be useful
# if you later want to render the Markdown report to HTML/PDF.
opt_patterns <- c("rmarkdown", "knitr")

inst <- rownames(installed.packages())
need <- setdiff(pkgs, inst)
if (length(need) > 0) {
  install.packages(need, repos = "https://cloud.r-project.org")
}
# don't auto-install optional packages (TMLE can be heavy)
message("Installed core pkgs. Optional (TMLE): ", paste(setdiff(opt, inst), collapse = ", "))
message("Optional (Patterns artifacts): ", paste(setdiff(opt_patterns, inst), collapse = ", "))
