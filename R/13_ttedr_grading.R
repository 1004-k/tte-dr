# R/13_ttedr_grading.R
# ------------------------------------------------------------
# Paper X: TTE-DR grading and if-then operating rules
# ------------------------------------------------------------

compute_ttedr_grade <- function(mod) {
  grade <- "Green"
  flags <- character(0)

  # Positivity
  if (!is.null(mod$positivity)) {
    if (isTRUE(mod$positivity$tipped_any)) {
      grade <- "Red"; flags <- c(flags, "positivity_tipped")
    } else {
      if (is.finite(mod$positivity$rESS_min_med) && mod$positivity$rESS_min_med < 0.15) {
        grade <- "Red"; flags <- c(flags, "ess_collapse")
      } else if (is.finite(mod$positivity$rESS_min_med) && mod$positivity$rESS_min_med < 0.25) {
        if (grade == "Green") grade <- "Amber"
        flags <- c(flags, "low_ess")
      }
      if (is.finite(mod$positivity$tail_share_max_med) && mod$positivity$tail_share_max_med > 0.20) {
        if (grade == "Green") grade <- "Amber"
        flags <- c(flags, "tail_concentration")
      }
    }
  }

  # Stability
  if (!is.null(mod$stability)) {
    # Direction changes around the null are recorded downstream as informational notes,
    # not as dominant grading flags.
    if (is.finite(mod$stability$est_range) && mod$stability$est_range > 0.20) {
      if (grade == "Green") grade <- "Amber"
      flags <- c(flags, "large_spec_range")
    }
  }

  # Residual sensitivity
  if (!is.null(mod$sensitivity)) {
    if (is.finite(mod$sensitivity$delta_star_med) && mod$sensitivity$delta_star_med < 0.5) {
      if (grade == "Green") grade <- "Amber"
      flags <- c(flags, "early_tipping")
    }
  }

  # Pressure for interpretation
  if (!is.null(mod$pressure)) {
    if (is.finite(mod$pressure$max_spd_med) && mod$pressure$max_spd_med > 0.8) {
      flags <- c(flags, "high_pressure")
    }
  }

  list(grade = grade, flags = unique(flags))
}
