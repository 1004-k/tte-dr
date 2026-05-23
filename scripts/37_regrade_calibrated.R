suppressPackageStartupMessages(library(data.table))
source("R/14_ttedr_reporting.R")

OUT_DIR <- Sys.getenv("OUT_DIR", "output_paperx_main")
infile  <- file.path(OUT_DIR, "ttdr_summary_by_scenario.csv")
stopifnot(file.exists(infile))

x <- fread(infile)
# Internal runs may use truth == "null"; exported tables convert this to "causal_null".
cal <- x[truth %in% c("null", "causal_null") & mis_spec == 0]

q <- function(v, p) as.numeric(quantile(v, probs = p, na.rm = TRUE, type = 8))
P_AMBER <- as.numeric(Sys.getenv("P_AMBER", "0.90"))
P_RED   <- as.numeric(Sys.getenv("P_RED",   "0.975"))

C_SPD_AMBER   <- q(cal$max_spd_med,   P_AMBER)
C_SPD_RED     <- q(cal$max_spd_med,   P_RED)
C_GAMMA_AMBER <- q(cal$Gamma_end_med, P_AMBER)
C_GAMMA_RED   <- q(cal$Gamma_end_med, P_RED)
C_RANGE_AMBER <- q(cal$est_range,     P_AMBER)
C_RANGE_RED   <- q(cal$est_range,     P_RED)
C_ESS  <- as.numeric(Sys.getenv("C_ESS",  "0.25"))
C_TAIL <- as.numeric(Sys.getenv("C_TAIL", "0.10"))

regrade <- function(row) {
  flags <- character()
  grade <- "Green"

  # Direction changes around the null are retained as informational notes only.
  direction_note <- isTRUE(row$sign_flip)

  if (isTRUE(row$tipped_any) ||
      (is.finite(row$rESS_min_med) && row$rESS_min_med < C_ESS) ||
      (is.finite(row$tail_share_max_med) && row$tail_share_max_med > C_TAIL)) {
    grade <- "Red"
    flags <- c(flags, "positivity_tipped")
  }

  if (grade != "Red") {
    if (is.finite(row$max_spd_med) && row$max_spd_med >= C_SPD_AMBER) {
      grade <- "Amber"; flags <- c(flags, "high_pressure")
    }
    if (is.finite(row$Gamma_end_med) && row$Gamma_end_med >= C_GAMMA_AMBER) {
      grade <- "Amber"; flags <- c(flags, "high_cum_pressure")
    }
    if (is.finite(row$est_range) && row$est_range >= C_RANGE_AMBER) {
      grade <- "Amber"; flags <- c(flags, "instability_across_specs")
    }

    extreme <- FALSE
    if (is.finite(row$max_spd_med) && row$max_spd_med >= C_SPD_RED) extreme <- TRUE
    if (is.finite(row$Gamma_end_med) && row$Gamma_end_med >= C_GAMMA_RED) extreme <- TRUE
    if (is.finite(row$est_range) && row$est_range >= C_RANGE_RED) extreme <- TRUE

    if (extreme) {
      grade <- "Red"
      flags <- c(flags, "extreme_signal")
    }
  }

  tpl <- make_discussion_templates(grade, flags, direction_note = direction_note)$full
  list(grade = grade, flags = paste(unique(flags), collapse = ";"), template = tpl)
}

tmp <- x[, regrade(.SD), by = .(scenario_id, mis_spec, truth)]
x[, `:=`(grade = tmp$grade, flags = tmp$flags, template = tmp$template)]
fwrite(x, infile)

cat("Calibration cutoffs:\n")
cat("  percentiles: amber=", P_AMBER, " red=", P_RED, "\n", sep = "")
cat("  max_spd_med: amber >=", C_SPD_AMBER, " red >=", C_SPD_RED, "\n")
cat("  Gamma_end_med: amber >=", C_GAMMA_AMBER, " red >=", C_GAMMA_RED, "\n")
cat("  est_range: amber >=", C_RANGE_AMBER, " red >=", C_RANGE_RED, "\n\n")
print(table(x$grade, useNA = "ifany"))
