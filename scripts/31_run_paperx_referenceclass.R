#!/usr/bin/env Rscript

source("R/00_utils.R")
cfg <- init_project(
  n_cores = as.integer(Sys.getenv("N_CORES", "4")),
  seed    = 2026L,
  out_dir = Sys.getenv("OUT_DIR", "output_paperx")
)
cfg$require_pkgs(c("data.table", "survival", "future.apply", "future"))

source("R/01_scenarios.R")
source("R/10_dgp_paperc.R")
source("R/03_spd_curve.R")
source("R/05_tipping.R")
source("R/04_pp_ipcw.R")
source("R/11_paperc_sensitivity.R")
source("R/12_ttedr_reference_class.R")
source("R/13_ttedr_grading.R")
source("R/14_ttedr_reporting.R")
source("R/15_ttedr_sensitivity_wrapper.R")

B     <- as.integer(Sys.getenv("B", "100"))
N     <- as.integer(Sys.getenv("N", "2000"))
t_max <- as.numeric(Sys.getenv("T_MAX", "5"))
dt    <- as.numeric(Sys.getenv("DT", "0.25"))
T_CUT <- as.numeric(Sys.getenv("T_CUT", as.character(t_max)))

MIS_SPEC_LEVELS <- as.integer(trimws(strsplit(Sys.getenv("MIS_SPEC_LEVELS", "0,1"), ",", fixed = TRUE)[[1]]))
MIS_SPEC_LEVELS <- MIS_SPEC_LEVELS[MIS_SPEC_LEVELS %in% c(0L,1L)]
if (length(MIS_SPEC_LEVELS) == 0) MIS_SPEC_LEVELS <- c(0L,1L)

TRUTH_LEVELS <- trimws(strsplit(Sys.getenv("TRUTH_LEVELS", "null"), ",", fixed = TRUE)[[1]])
TRUTH_LEVELS <- TRUTH_LEVELS[TRUTH_LEVELS %in% c("null","non_null")]
if (length(TRUTH_LEVELS) == 0) TRUTH_LEVELS <- c("null")

BETA_TRUE_PP <- as.numeric(Sys.getenv("BETA_TRUE_PP", "0"))

# Stability specs: horizon set in same time units as t_max
HORIZON_SET <- as.numeric(trimws(strsplit(Sys.getenv("HORIZON_SET", paste0(max(1, t_max-2), ",", max(1, t_max-1), ",", t_max)), ",", fixed = TRUE)[[1]]))
HORIZON_SET <- HORIZON_SET[is.finite(HORIZON_SET) & HORIZON_SET > 0]
if (length(HORIZON_SET) == 0) HORIZON_SET <- c(T_CUT)

# Sensitivity
DELTA_MAX  <- as.numeric(Sys.getenv("DELTA_MAX", "2.0"))
DELTA_STEP <- as.numeric(Sys.getenv("DELTA_STEP", "0.1"))
delta_grid <- seq(0, DELTA_MAX, by = DELTA_STEP)
DELTA_SHAPE <- Sys.getenv("DELTA_SHAPE", "late_only")
T0_SENS <- as.numeric(Sys.getenv("T0_SENS", as.character(0.7 * t_max)))
DECISION_MODE <- Sys.getenv("DECISION_MODE", "cross_zero")

# DGP axis fixed for reference-class run
DELTA_DGM <- Sys.getenv("DELTA_DGM", "D1_zero")
DELTA_MAG <- as.numeric(Sys.getenv("DELTA_MAG", "0.6"))
T0_DELTA  <- as.numeric(Sys.getenv("T0_DELTA", "3.5"))
CORR_MEAS_UNM <- as.numeric(Sys.getenv("CORR_MEAS_UNM", "0.0"))

BREAK_DT <- as.numeric(Sys.getenv("BREAK_DT", "1.0"))
breaks <- seq(0, t_max, by = BREAK_DT)
if (tail(breaks, 1) < t_max) breaks <- c(breaks, t_max)

c_ess  <- as.numeric(Sys.getenv("C_ESS", "0.25"))
c_tail <- as.numeric(Sys.getenv("C_TAIL", "0.10"))

subset_ids <- trimws(strsplit(Sys.getenv("SCENARIO_SUBSET", ""), ",", fixed = TRUE)[[1]])
subset_ids <- subset_ids[nzchar(subset_ids)]

safe_max <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  max(x)
}
safe_min <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  min(x)
}

# Grid
base_grid <- make_scenario_grid()
if (length(subset_ids) > 0) base_grid <- base_grid[scenario_id %in% subset_ids]

jobs <- data.table::CJ(
  scenario_id = base_grid$scenario_id,
  mis_spec    = MIS_SPEC_LEVELS,
  truth       = TRUTH_LEVELS,
  replicate   = seq_len(B),
  unique      = TRUE
)
jobs <- merge(jobs, base_grid, by = "scenario_id", all.x = TRUE)
data.table::setorder(jobs, scenario_num, mis_spec, truth, replicate)

raw_dir <- file.path(cfg$out_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

future::plan(future::multisession, workers = cfg$n_cores)

run_one <- function(row) {
  truth <- as.character(row[["truth"]])
  if (length(truth) != 1L || !nzchar(truth)) truth <- "null"
  beta <- if (identical(truth, "non_null")) BETA_TRUE_PP else 0

  seed <- seed_for_job(cfg$seed * 300000L, row[["scenario_id"]], truth = paste0(truth, "_", DELTA_DGM), rep_id = row[["replicate"]])

  sim <- simulate_one_dataset_paperc(
    N = N, t_max = t_max, dt = dt,
    beta_true = beta,
    axisA = row[["axisA"]],
    axisB = row[["axisB"]],
    rho_meas = row[["rho_meas"]],
    delta_dgm = DELTA_DGM,
    delta_mag = DELTA_MAG,
    t0_delta = T0_DELTA,
    corr_meas_unm = CORR_MEAS_UNM,
    seed = seed
  )

  long_dt <- sim$long_dt
  pp_dt   <- sim$pp_dt

  # Pressure (SPD(t)): deviation-event hazard per 1 SD higher z_obs within each time bin
  spd_input <- data.table::copy(long_dt)
  spd_input <- merge(spd_input, pp_dt[, .(id, dev_time, dev_ind)], by = "id", all.x = TRUE)
  spd_input[is.na(dev_time), dev_time := Inf]

  # truncate each subject's follow-up at deviation time
  spd_input[tstop > dev_time, tstop := dev_time]
  spd_input <- spd_input[tstop > tstart]
  data.table::setorder(spd_input, id, tstart)

  # deviation event occurs in the interval containing dev_time
  spd_input[, dev_event := as.integer(dev_ind == 1L & tstart < dev_time & dev_time <= tstop)]

  # assign time bins by tstart
  spd_input[, bin := findInterval(tstart, vec = breaks, rightmost.closed = TRUE)]
  spd_input <- spd_input[bin >= 1 & bin < length(breaks)]

  spd_rows <- lapply(seq_len(length(breaks) - 1L), function(k) {
    t1 <- breaks[k]; t2 <- breaks[k + 1L]
    dt_k <- spd_input[bin == k]
    n_events <- sum(dt_k$dev_event, na.rm = TRUE)
    sd_z <- stats::sd(dt_k$z_obs, na.rm = TRUE)

    if (!is.finite(sd_z) || sd_z <= 0 || n_events == 0) {
      return(data.table::data.table(
        interval = k, gamma_hat = NA_real_, se = NA_real_,
        HR_1SD = NA_real_, CI_low = NA_real_, CI_high = NA_real_,
        tstart = t1, tstop = t2, t_mid = (t1 + t2) / 2
      ))
    }

    dt_k[, z_std := z_obs / sd_z]

    fit <- try(
      survival::coxph(
        survival::Surv(tstart, tstop, dev_event) ~ z_std,
        data = dt_k,
        ties = "efron"
      ),
      silent = TRUE
    )

    if (inherits(fit, "try-error")) {
      return(data.table::data.table(
        interval = k, gamma_hat = NA_real_, se = NA_real_,
        HR_1SD = NA_real_, CI_low = NA_real_, CI_high = NA_real_,
        tstart = t1, tstop = t2, t_mid = (t1 + t2) / 2
      ))
    }

    b <- stats::coef(fit)[["z_std"]]
    V <- stats::vcov(fit)
    se <- sqrt(V["z_std", "z_std"])

    data.table::data.table(
      interval = k,
      gamma_hat = as.numeric(b),
      se = as.numeric(se),
      HR_1SD = exp(as.numeric(b)),
      CI_low = exp(as.numeric(b) - 1.96 * as.numeric(se)),
      CI_high = exp(as.numeric(b) + 1.96 * as.numeric(se)),
      tstart = t1, tstop = t2, t_mid = (t1 + t2) / 2
    )
  })

  spd_tbl <- data.table::rbindlist(spd_rows)

  # cumulative pressure (treat missing bins as 0 contribution)
  gh <- spd_tbl$gamma_hat
  gh_int <- gh
  gh_int[!is.finite(gh_int)] <- 0
  spd_tbl[, Gamma_hat := cumsum(gh_int * (tstop - tstart))]

  max_spd <- safe_max(abs(spd_tbl$gamma_hat))
  Gamma_end <- safe_max(spd_tbl$Gamma_hat)

  # Censoring model (mis-spec knob)
  cens_fml <- if (row[["mis_spec"]] == 1L) {
    survival::Surv(time_pp, dev_ind) ~ A0 + age + sex + bmi
  } else {
    survival::Surv(time_pp, dev_ind) ~ A0 + age + sex + bmi + egfr + util + gall
  }

  fit_cens <- survival::coxph(cens_fml, data = pp_dt, model = TRUE, x = TRUE)
  fit_cens$bh0 <- survival::basehaz(fit_cens, centered = FALSE)
  lp_cens <- stats::predict(fit_cens, type = "lp")

  t_eval <- sort(unique(long_dt$tstart))
  weights_dt <- data.table::CJ(id = pp_dt$id, t = t_eval, unique = TRUE)
  weights_dt <- merge(weights_dt, data.table::data.table(id = pp_dt$id, lp = lp_cens), by = "id", all.x = TRUE)
  weights_dt[, S := get_S_from_cox(fit_cens, time_vec = t, lp_vec = lp)]
  weights_dt[, w := 1 / pmax(S, 1e-3)]

  diag_dt <- compute_weight_diagnostics(long_dt, weights_dt, time_col = "tstart", id_col = "id", w_col = "w", q_tail = 0.99)
  tip <- detect_tipping(diag_dt, c_ess = c_ess, c_tail = c_tail)

  rESS_min <- safe_min(tip$diag$rESS)
  tail_share_max <- safe_max(tip$diag$tail_share)
  tipped_any <- isTRUE(any(tip$diag$tipped == 1, na.rm = TRUE))

  # Stability: horizon sensitivity
  est_by_h <- lapply(HORIZON_SET, function(h) {
    r <- fit_ipcw_risk(pp_dt = pp_dt, t_cut = h, fit_cens = fit_cens, lp = lp_cens, w_floor = 1e-3)
    data.table::data.table(horizon = h, logrr = r$logrr)
  })
  est_by_h <- data.table::rbindlist(est_by_h)
  est_range <- safe_max(est_by_h$logrr) - safe_min(est_by_h$logrr)
  sign_flip <- (any(est_by_h$logrr > 0, na.rm = TRUE) && any(est_by_h$logrr < 0, na.rm = TRUE))

  # Residual sensitivity: delta-star for IPCW risk at T_CUT
  sens <- compute_delta_tipping(
    pp_dt = pp_dt,
    t_cut = T_CUT,
    breaks = breaks,
    delta_grid = delta_grid,
    shape = DELTA_SHAPE,
    t0 = T0_SENS,
    decision_mode = DECISION_MODE,
    base_estimator = "ipcw",
    cens_formula = cens_fml,
    mis_spec = row[["mis_spec"]],
    w_floor = 1e-3
  )

  data.table::data.table(
    scenario_id = row[["scenario_id"]],
    axisA = row[["axisA"]],
    axisB = row[["axisB"]],
    rho_meas = row[["rho_meas"]],
    mis_spec = row[["mis_spec"]],
    truth = truth,
    replicate = row[["replicate"]],
    max_spd = max_spd,
    Gamma_end = Gamma_end,
    rESS_min = rESS_min,
    tail_share_max = tail_share_max,
    tipped_any = as.integer(tipped_any),
    est_range = est_range,
    sign_flip = as.integer(sign_flip),
    delta_star = sens$delta_star
  )
}

# Run jobs
res <- future.apply::future_lapply(seq_len(nrow(jobs)), function(i) run_one(as.list(jobs[i, ])), future.seed = TRUE)
rep_dt <- data.table::rbindlist(res, fill = TRUE)

data.table::fwrite(rep_dt, file.path(raw_dir, "replicate_ttedr_panels.csv"))

# Scenario-level summaries
pressure_sum <- rep_dt[, .(
  max_spd_med = stats::median(max_spd, na.rm = TRUE),
  Gamma_end_med = stats::median(Gamma_end, na.rm = TRUE)
), by = .(scenario_id, mis_spec, truth)]

pos_sum <- rep_dt[, .(
  rESS_min_med = stats::median(rESS_min, na.rm = TRUE),
  tail_share_max_med = stats::median(tail_share_max, na.rm = TRUE),
  tipped_any = isTRUE(any(tipped_any == 1, na.rm = TRUE))
), by = .(scenario_id, mis_spec, truth)]

stab_sum <- rep_dt[, .(
  est_range = stats::median(est_range, na.rm = TRUE),
  sign_flip = isTRUE(any(sign_flip == 1, na.rm = TRUE))
), by = .(scenario_id, mis_spec, truth)]

sens_sum <- rep_dt[, .(
  delta_star_med = stats::median(delta_star, na.rm = TRUE)
), by = .(scenario_id, mis_spec, truth)]

sum_dt <- merge(pressure_sum, pos_sum, by = c("scenario_id","mis_spec","truth"))
sum_dt <- merge(sum_dt, stab_sum, by = c("scenario_id","mis_spec","truth"))
sum_dt <- merge(sum_dt, sens_sum, by = c("scenario_id","mis_spec","truth"), all.x = TRUE)

# Grade and templates
sum_dt[, c("grade","flags","template") := {
  mod <- list(
    pressure = list(max_spd_med = max_spd_med, Gamma_end_med = Gamma_end_med),
    positivity = list(rESS_min_med = rESS_min_med, tail_share_max_med = tail_share_max_med, tipped_any = tipped_any),
    stability = list(est_range = est_range, sign_flip = sign_flip),
    sensitivity = list(delta_star_med = delta_star_med)
  )
  g <- compute_ttedr_grade(mod)
  tpl <- make_discussion_templates(g$grade, g$flags)
  list(g$grade, paste(g$flags, collapse = ";"), tpl$full)
}, by = .(scenario_id, mis_spec, truth)]

data.table::fwrite(sum_dt, file.path(cfg$out_dir, "ttdr_summary_by_scenario.csv"))

# Reference class map
ref_map <- get_reference_class_map(base_grid)
pool <- sum_dt[truth == "null" & mis_spec == min(mis_spec)]
ref_map2 <- update_reference_class_map(
  ref_map,
  diag_summary = pool[, .(scenario_id, rESS_min_med, tail_share_max_med)],
  stability_summary = pool[, .(scenario_id, est_range)],
  sens_summary = pool[, .(scenario_id, delta_star_med)],
  pressure_summary = pool[, .(scenario_id, max_spd_med)]
)

data.table::fwrite(ref_map2, file.path(cfg$out_dir, "TableX1_reference_class_map.csv"))

message("Saved Paper X outputs under: ", cfg$out_dir)
