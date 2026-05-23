# R/14_ttedr_reporting.R
# ------------------------------------------------------------
# TTE-DR report text templates
# ------------------------------------------------------------

make_discussion_templates <- function(grade, flags, direction_note = FALSE) {
  flags <- unique(flags)
  flags <- flags[flags != "sign_flip_across_specs"]

  core <- switch(
    grade,
    Green = "Across the pre-specified diagnostic panel, no dominant warning signal crossed the calibrated thresholds.",
    Amber = "Diagnostics suggested potential fragility; conclusions should be interpreted with the pre-specified sensitivity results.",
    Red   = "Diagnostics indicated substantial fragility; decision-grade conclusions were not supported under the pre-specified QA panel.",
    "Diagnostics were inconclusive."
  )

  add <- character(0)
  if (any(c("positivity_tipped", "ess_collapse", "low_ess", "tail_concentration") %in% flags)) {
    add <- c(add, "Weight diagnostics indicated limited overlap, consistent with a positivity threat.")
  }
  if (any(c("large_spec_range", "instability_across_specs", "specification_instability") %in% flags)) {
    add <- c(add, "The conclusion was sensitive to the pre-specified specification set.")
  }
  if ("early_tipping" %in% flags) {
    add <- c(add, "A modest residual selection departure was sufficient to tip the conclusion under the specified sensitivity model.")
  }
  if (any(c("high_pressure", "high_cum_pressure", "high_cumulative_pressure") %in% flags)) {
    add <- c(add, "Selection pressure increased over follow-up, suggesting prognosis-dependent deviation.")
  }
  if (isTRUE(direction_note)) {
    add <- c(add, "Direction changes around the causal null were recorded as informational notes rather than grading flags.")
  }

  list(core = core, full = paste(c(core, add), collapse = " "))
}
