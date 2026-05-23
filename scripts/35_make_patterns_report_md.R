#!/usr/bin/env Rscript

# Build a lightweight Markdown report that summarizes the TTE-DR outputs.

source("R/00_utils.R")
cfg <- init_project(n_cores = 1L, seed = 2026L, out_dir = Sys.getenv("OUT_DIR", "output_paperx_main"))
cfg$require_pkgs(c("data.table"))

sum_path <- file.path(cfg$out_dir, "ttdr_summary_by_scenario.csv")
ref_path <- file.path(cfg$out_dir, "TableX1_reference_class_map.csv")
if (!file.exists(sum_path) || !file.exists(ref_path)) {
  stop("Missing required outputs. Run scripts/31_run_paperx_referenceclass.R first.")
}

sum_dt <- data.table::fread(sum_path, keepLeadingZeros = TRUE, showProgress = FALSE)
ref_dt <- data.table::fread(ref_path, keepLeadingZeros = TRUE, showProgress = FALSE)
canon <- sum_dt[truth %in% c("null", "causal_null") & mis_spec == 0]

score_grade <- function(g) {
  if (g == "Red") return(3)
  if (g == "Amber") return(2)
  if (g == "Green") return(1)
  0
}
canon[, grade_score := vapply(grade, score_grade, numeric(1))]
canon <- canon[order(-grade_score, -max_spd_med, rESS_min_med)]
rep_row <- canon[1]
rep_id <- as.character(rep_row$scenario_id)

clean_flags <- function(s) {
  flags <- trimws(strsplit(as.character(s), ";", fixed = TRUE)[[1]])
  flags <- flags[nzchar(flags) & flags != "sign_flip_across_specs"]
  if (length(flags) == 0) "none" else paste(unique(flags), collapse = "; ")
}
delta_display <- function(x, delta_max = 2.0) {
  s <- as.character(x)
  if (is.na(x) || !nzchar(s) || s %in% c("NA", "NaN")) return(paste0(">", delta_max, "; no tipping within range"))
  s
}

report_dir <- file.path(cfg$out_dir, "report")
dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)
md_path <- file.path(report_dir, "TTE-DR_report.md")
fig_dir <- file.path(cfg$out_dir, "figures")
fig_heat <- file.path(fig_dir, "Figure_1_TTEDR_grade_heatmap.pdf")
fig_panel <- file.path(fig_dir, "Figure_2_reference_class_representatives.pdf")
fig_snap  <- file.path(fig_dir, "Figure_3_TTEDR_diagnostic_snapshot.pdf")

rel <- function(p) if (file.exists(p)) paste0("../", basename(dirname(p)), "/", basename(p)) else "(not generated)"

cat(
  "# TTE-DR Diagnostic Report (auto-generated)\n\n",
  "This report summarizes the TTE-DR QA panel outputs for the reference-class simulation run.\n\n",
  "## Run metadata\n\n",
  "- Generated (UTC): ", format(Sys.time(), tz = "UTC", usetz = TRUE), "\n",
  "- Output directory: `", cfg$out_dir, "`\n",
  "- Canonical slice: `truth = causal_null`, `mis_spec = 0`\n\n",
  "Session information and run metadata are saved under `", file.path(cfg$out_dir, "logs"), "`.\n\n",
  sep = "",
  file = md_path
)

cat(
  "## Example scenario for a one-page snapshot\n\n",
  "- Scenario: **", rep_id, "**\n",
  "- Grade: **", as.character(rep_row$grade), "**\n",
  "- Dominant flags: `", clean_flags(rep_row$flags), "`\n",
  "- Direction change note: `", ifelse(isTRUE(rep_row$sign_flip), "noted", "none"), "`\n\n",
  "Key panel summaries (medians over replicates):\n\n",
  "- max |SPD(t)|: ", sprintf("%.3f", rep_row$max_spd_med), "\n",
  "- min rESS: ", sprintf("%.3f", rep_row$rESS_min_med), "\n",
  "- max tail share: ", sprintf("%.3f", rep_row$tail_share_max_med), "\n",
  "- horizon logRR range: ", sprintf("%.3f", rep_row$est_range), "\n",
  "- delta*: ", delta_display(rep_row$delta_star_med), "\n\n",
  "Template interpretation:\n\n",
  "> ", as.character(rep_row$template), "\n\n",
  sep = "",
  file = md_path,
  append = TRUE
)

cat(
  "## Figures\n\n",
  "- Figure 1: ", rel(fig_heat), "\n",
  "- Figure 2: ", rel(fig_panel), "\n",
  "- Figure 3: ", rel(fig_snap), "\n\n",
  sep = "",
  file = md_path,
  append = TRUE
)

message("Saved Markdown report: ", md_path)
