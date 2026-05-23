#!/usr/bin/env Rscript

source("R/00_utils.R")
cfg <- init_project(n_cores = 1L, seed = 2026L, out_dir = Sys.getenv("OUT_DIR", "output_paperx_main"))
cfg$write_session_info("paperx_tables")
cfg$write_run_metadata("paperx_tables")
cfg$require_pkgs(c("data.table"))

out_tab <- file.path(cfg$out_dir, "tables")
dir.create(out_tab, showWarnings = FALSE, recursive = TRUE)

clean_truth <- function(x) {
  x <- as.character(x)
  x[is.na(x) | x == "" | x == "null"] <- "causal_null"
  x
}
clean_flags <- function(x) {
  vapply(as.character(x), function(s) {
    flags <- trimws(strsplit(s, ";", fixed = TRUE)[[1]])
    flags <- flags[nzchar(flags) & flags != "sign_flip_across_specs"]
    flags <- gsub("high_cum_pressure", "high_cumulative_pressure", flags, fixed = TRUE)
    flags <- gsub("instability_across_specs", "specification_instability", flags, fixed = TRUE)
    if (length(flags) == 0) "none" else paste(unique(flags), collapse = "; ")
  }, character(1))
}
direction_note <- function(x) ifelse(as.logical(x), "direction change noted", "none")
delta_display <- function(x, delta_max = 2.0) {
  out <- as.character(x)
  bad <- is.na(x) | !nzchar(out) | out %in% c("NA", "NaN")
  out[bad] <- paste0(">", delta_max, " (no tipping within evaluated range)")
  out
}

ref_path <- file.path(cfg$out_dir, "TableX1_reference_class_map.csv")
if (!file.exists(ref_path)) stop("Missing: ", ref_path)
ref <- data.table::fread(ref_path, showProgress = FALSE)
label_map <- c(
  A1_baseline_none = "A1_baseline_none",
  B1_threshold_jump = "B1_threshold_jump",
  B2_monotone_increasing = "B2_monotone_increasing",
  B3_late_surge = "B3_late_surge",
  B4_feedback_loop = "B4_feedback_loop",
  B5_early_frailty_dropout = "B5_early_frailty_dropout",
  C1_positivity_moderate = "C1_lower_overlap",
  C2_positivity_severe = "C2_strongest_observed_overlap_stress",
  D1_spec_instability = "D1_specification_instability",
  D2_sensitivity_no_tipping = "D2_sensitivity_no_tipping"
)
ref[, failure_mode := ifelse(failure_mode %in% names(label_map), label_map[failure_mode], failure_mode)]
data.table::setnames(ref, "fixed", "fixed_anchor", skip_absent = TRUE)
data.table::fwrite(ref[, .(failure_mode, scenario_id, fixed_anchor)], file.path(out_tab, "Table_1_reference_class_representatives.csv"))

sum_path <- file.path(cfg$out_dir, "ttdr_summary_by_scenario.csv")
if (!file.exists(sum_path)) stop("Missing: ", sum_path)
sum_dt <- data.table::fread(sum_path, keepLeadingZeros = TRUE, showProgress = FALSE)
sum_dt[, truth := clean_truth(truth)]
sum_dt[, dominant_flags := clean_flags(flags)]
sum_dt[, direction_note := direction_note(sign_flip)]
sum_dt[, delta_star := delta_display(delta_star_med, delta_max = as.numeric(Sys.getenv("DELTA_MAX", "2.0")))]

main_tab <- sum_dt[truth == "causal_null" & mis_spec == 0]
main_tab <- main_tab[, .(
  scenario_id,
  max_abs_spd_median = round(max_spd_med, 3),
  end_pressure_median = round(Gamma_end_med, 3),
  min_ress_median = round(rESS_min_med, 3),
  max_tail_share_median = round(tail_share_max_med, 3),
  logrr_range_median = round(est_range, 3),
  direction_note,
  delta_star,
  grade,
  dominant_flags
)]
data.table::fwrite(main_tab, file.path(out_tab, "Table_2_canonical_slice_summary.csv"))

full_tab <- sum_dt[, .(
  scenario_id, mis_spec, truth,
  max_spd_med = round(max_spd_med, 3),
  Gamma_end_med = round(Gamma_end_med, 3),
  rESS_min_med = round(rESS_min_med, 3),
  tail_share_max_med = round(tail_share_max_med, 3),
  est_range = round(est_range, 3),
  direction_note, delta_star, grade, dominant_flags, template
)]
data.table::fwrite(full_tab, file.path(out_tab, "Table_S1_full_TTEDR_summary.csv"))

message("Saved clean tables under: ", out_tab)
