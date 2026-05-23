#!/usr/bin/env Rscript

# Methods compatibility demo for Paper X
# - Runs a small subset and compares grades when the baseline estimator is changed

source("R/00_utils.R")
cfg <- init_project(
  n_cores = as.integer(Sys.getenv("N_CORES", "4")),
  seed    = 2026L,
  out_dir = Sys.getenv("OUT_DIR", "output_paperx_methods")
)
cfg$write_session_info("paperx_methods")
cfg$write_run_metadata("paperx_methods")
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
source("R/09_dr_aipw_ml.R")

B     <- as.integer(Sys.getenv("B", "50"))
N     <- as.integer(Sys.getenv("N", "2000"))
t_max <- as.numeric(Sys.getenv("T_MAX", "5"))
dt    <- as.numeric(Sys.getenv("DT", "0.25"))
T_CUT <- as.numeric(Sys.getenv("T_CUT", as.character(t_max)))

subset_ids <- trimws(strsplit(Sys.getenv("SCENARIO_SUBSET", "S01,S09,S18"), ",", fixed = TRUE)[[1]])
subset_ids <- subset_ids[nzchar(subset_ids)]

MIS_SPEC_LEVELS <- as.integer(trimws(strsplit(Sys.getenv("MIS_SPEC_LEVELS", "0"), ",", fixed = TRUE)[[1]]))
MIS_SPEC_LEVELS <- MIS_SPEC_LEVELS[MIS_SPEC_LEVELS %in% c(0L,1L)]
if (length(MIS_SPEC_LEVELS) == 0) MIS_SPEC_LEVELS <- c(0L)

DELTA_MAX  <- as.numeric(Sys.getenv("DELTA_MAX", "2.0"))
DELTA_STEP <- as.numeric(Sys.getenv("DELTA_STEP", "0.1"))
delta_grid <- seq(0, DELTA_MAX, by = DELTA_STEP)
DELTA_SHAPE <- Sys.getenv("DELTA_SHAPE", "late_only")
T0_SENS <- as.numeric(Sys.getenv("T0_SENS", as.character(0.7 * t_max)))
DECISION_MODE <- Sys.getenv("DECISION_MODE", "cross_zero")

BREAK_DT <- as.numeric(Sys.getenv("BREAK_DT", "1.0"))
breaks <- seq(0, t_max, by = BREAK_DT)
if (tail(breaks, 1) < t_max) breaks <- c(breaks, t_max)

DELTA_DGM <- Sys.getenv("DELTA_DGM", "D1_zero")
DELTA_MAG <- as.numeric(Sys.getenv("DELTA_MAG", "0.6"))
T0_DELTA  <- as.numeric(Sys.getenv("T0_DELTA", "3.5"))
CORR_MEAS_UNM <- as.numeric(Sys.getenv("CORR_MEAS_UNM", "0.0"))

c_ess  <- as.numeric(Sys.getenv("C_ESS", "0.25"))
c_tail <- as.numeric(Sys.getenv("C_TAIL", "0.10"))

# Estimators to compare
EST_SET <- trimws(strsplit(Sys.getenv("EST_SET", "ipcw,dr_glm,tmle"), ",", fixed = TRUE)[[1]])
EST_SET <- EST_SET[EST_SET %in% c("ipcw","dr_glm","tmle")]
if (length(EST_SET) == 0) EST_SET <- c("ipcw","dr_glm")

raw_dir <- file.path(cfg$out_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

base_grid <- make_scenario_grid()
base_grid <- base_grid[scenario_id %in% subset_ids]

jobs <- data.table::CJ(
  scenario_id = base_grid$scenario_id,
  mis_spec = MIS_SPEC_LEVELS,
  estimator = EST_SET,
  replicate = seq_len(B),
  unique = TRUE
)
jobs <- merge(jobs, base_grid, by = "scenario_id", all.x = TRUE)

future::plan(future::multisession, workers = cfg$n_cores)

run_one <- function(row) {
  seed <- seed_for_job(cfg$seed * 500000L, row$scenario_id, truth = paste0(row$estimator, "_", DELTA_DGM), rep_id = row$replicate)

  sim <- simulate_one_dataset_paperc(
    N = N, t_max = t_max, dt = dt,
    beta_true = 0,
    axisA = row$axisA,
    axisB = row$axisB,
    rho_meas = row$rho_meas,
    delta_dgm = DELTA_DGM,
    delta_mag = DELTA_MAG,
    t0_delta = T0_DELTA,
    corr_meas_unm = CORR_MEAS_UNM,
    seed = seed
  )

  long_dt <- sim$long_dt
  pp_dt   <- sim$pp_dt

  spd_fit <- estimate_spd_piecewise(long_dt, breaks = breaks, z_col = "z_obs", dev_col = "dev", id_col = "id", robust = TRUE)
  spd_dt <- compute_cum_pressure(spd_fit$spd)
  max_spd <- max(abs(spd_dt$gamma_hat), na.rm = TRUE)

  cens_fml <- if (row$mis_spec == 1L) {
    survival::Surv(time_pp, dev_ind) ~ A0 + age + sex + bmi
  } else {
    survival::Surv(time_pp, dev_ind) ~ A0 + age + sex + bmi + egfr + util + gall
  }

  fit_cens <- survival::coxph(cens_fml, data = pp_dt, model = TRUE, x = TRUE)
  fit_cens$bh0 <- survival::basehaz(fit_cens, centered = FALSE)
  lp_cens <- stats::predict(fit_cens, type = "lp")

  t_eval <- sort(unique(long_dt$tstart))
  weights_dt <- data.table::CJ(id = pp_dt$id, t = t_eval)
  weights_dt <- merge(weights_dt, data.table::data.table(id = pp_dt$id, lp = lp_cens), by = "id", all.x = TRUE)
  weights_dt[, S := get_S_from_cox(fit_cens, time_vec = t, lp_vec = lp)]
  weights_dt[, w := 1 / pmax(S, 1e-3)]
  diag_dt <- compute_weight_diagnostics(long_dt, weights_dt, time_col = "tstart", id_col = "id", w_col = "w", q_tail = 0.99)
  tip <- detect_tipping(diag_dt, c_ess = c_ess, c_tail = c_tail)

  sens <- compute_delta_tipping(
    pp_dt = pp_dt,
    t_cut = T_CUT,
    breaks = breaks,
    delta_grid = delta_grid,
    shape = DELTA_SHAPE,
    t0 = T0_SENS,
    decision_mode = DECISION_MODE,
    base_estimator = row$estimator,
    cens_formula = cens_fml,
    mis_spec = row$mis_spec,
    seed = seed + 17L
  )

  data.table::data.table(
    scenario_id = row$scenario_id,
    mis_spec = row$mis_spec,
    estimator = row$estimator,
    replicate = row$replicate,
    max_spd = max_spd,
    rESS_min = min(tip$diag$rESS, na.rm = TRUE),
    tail_share_max = max(tip$diag$tail_share, na.rm = TRUE),
    delta_star = sens$delta_star
  )
}

res <- future.apply::future_lapply(seq_len(nrow(jobs)), function(i) run_one(as.list(jobs[i, ])), future.seed = TRUE)
rep_dt <- data.table::rbindlist(res, fill = TRUE)

data.table::fwrite(rep_dt, file.path(raw_dir, "replicate_methods_demo.csv"))

# scenario-level summary and grade per estimator
sum_dt <- rep_dt[, .(
  max_spd_med = stats::median(max_spd, na.rm = TRUE),
  rESS_min_med = stats::median(rESS_min, na.rm = TRUE),
  tail_share_max_med = stats::median(tail_share_max, na.rm = TRUE),
  delta_star_med = stats::median(delta_star, na.rm = TRUE)
), by = .(scenario_id, mis_spec, estimator)]

sum_dt[, c("grade","flags") := {
  mod <- list(
    pressure = list(max_spd_med = max_spd_med),
    positivity = list(rESS_min_med = rESS_min_med, tail_share_max_med = tail_share_max_med, tipped_any = FALSE),
    stability = list(est_range = 0, sign_flip = FALSE),
    sensitivity = list(delta_star_med = delta_star_med)
  )
  g <- compute_ttedr_grade(mod)
  list(g$grade, paste(g$flags, collapse = ";"))
}, by = .(scenario_id, mis_spec, estimator)]

data.table::fwrite(sum_dt, file.path(cfg$out_dir, "ttdr_methods_compare.csv"))
message("Saved methods demo outputs under: ", cfg$out_dir)
