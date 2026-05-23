# R/12_ttedr_reference_class.R
# ------------------------------------------------------------
# Paper X: TTE-DR reference-class definitions
# ------------------------------------------------------------

get_reference_class_map <- function(grid_dt) {
  stopifnot(all(c("scenario_id","axisA","axisB","rho_meas","panel_title") %in% names(grid_dt)))

  # Fixed anchors (stable, based on meta labels)
  sid_none <- grid_dt[axisA == "flat" & axisB == "none", scenario_id][1]
  sid_jump <- grid_dt[axisB == "threshold_jump", scenario_id][1]
  sid_inc  <- grid_dt[axisA == "increasing", scenario_id][1]

  # Placeholders for remaining modes; updated after a run
  data.table::data.table(
    failure_mode = c(
      "A1_baseline_none",
      "B1_threshold_jump",
      "B2_monotone_increasing",
      "B3_late_surge",
      "B4_feedback_loop",
      "B5_early_frailty_dropout",
      "C1_lower_overlap",
      "C2_strongest_observed_overlap_stress",
      "D1_specification_instability",
      "D2_sensitivity_no_tipping"
    ),
    scenario_id = c(
      sid_none,
      sid_jump,
      sid_inc,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_
    ),
    fixed = c(TRUE, TRUE, TRUE, rep(FALSE, 7))
  )
}

# Update mapping using scenario-level summaries
update_reference_class_map <- function(ref_map, diag_summary, stability_summary, sens_summary, pressure_summary = NULL) {
  # diag_summary columns: scenario_id, rESS_min_med, tail_share_max_med
  # stability_summary columns: scenario_id, est_range
  # sens_summary columns: scenario_id, delta_star_med
  # pressure_summary optional: scenario_id, max_spd_med

  if (!is.null(pressure_summary)) {
    # Late surge and feedback loop are placeholders; here we pick two high-pressure scenarios
    top <- pressure_summary[order(-max_spd_med)][1:3, scenario_id]
    if (length(top) >= 1) ref_map[failure_mode == "B3_late_surge", scenario_id := top[1]]
    if (length(top) >= 2) ref_map[failure_mode == "B4_feedback_loop", scenario_id := top[2]]
    if (length(top) >= 3) ref_map[failure_mode == "B5_early_frailty_dropout", scenario_id := top[3]]
  }

  if (!is.null(diag_summary)) {
    # strongest observed overlap stress: smallest rESS, then largest tail
    sev <- diag_summary[order(rESS_min_med, -tail_share_max_med)][1, scenario_id]
    # lower-overlap representative: near the nominal lower-overlap target, not extreme tail
    mod <- diag_summary[order(abs(rESS_min_med - 0.25), tail_share_max_med)][1, scenario_id]
    ref_map[failure_mode == "C2_strongest_observed_overlap_stress", scenario_id := sev]
    ref_map[failure_mode == "C1_lower_overlap", scenario_id := mod]
  }

  if (!is.null(stability_summary)) {
    sid <- stability_summary[order(-est_range)][1, scenario_id]
    ref_map[failure_mode == "D1_specification_instability", scenario_id := sid]
  }

  if (!is.null(sens_summary)) {
    sid <- sens_summary[order(delta_star_med)][1, scenario_id]
    ref_map[failure_mode == "D2_sensitivity_no_tipping", scenario_id := sid]
  }

  ref_map
}
