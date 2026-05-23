# R/15_ttedr_sensitivity_wrapper.R
# ------------------------------------------------------------
# Paper X: delta tipping wrapper
# - Baseline estimator can be IPCW risk, DR-AIPW risk, or TMLE risk
# - Sensitivity movement is based on anchored_theta_curve
# ------------------------------------------------------------

compute_delta_tipping <- function(pp_dt,
                                 t_cut,
                                 breaks,
                                 delta_grid,
                                 shape = c("late_only","constant","sign_change"),
                                 t0 = NULL,
                                 decision_mode = c("cross_zero","sign"),
                                 base_estimator = c("ipcw","dr_glm","tmle"),
                                 cens_formula,
                                 mis_spec = 0L,
                                 w_floor = 1e-3,
                                 dr_use_ml = FALSE,
                                 ml_method = "glmnet",
                                 crossfit = FALSE,
                                 cf_folds = 2L,
                                 seed = 1L) {

  shape <- match.arg(shape, c("late_only","constant","sign_change"))
  decision_mode <- match.arg(decision_mode, c("cross_zero","sign"))
  base_estimator <- match.arg(base_estimator, c("ipcw","dr_glm","tmle"))

  # Baseline theta0 at delta=0
  theta0_logrr <- NA_real_
  theta0_rd <- NA_real_

  if (base_estimator == "ipcw") {
    fit_cens <- survival::coxph(cens_formula, data = pp_dt, model = TRUE, x = TRUE)
    fit_cens$bh0 <- survival::basehaz(fit_cens, centered = FALSE)
    lp <- stats::predict(fit_cens, type = "lp")
    base <- fit_ipcw_risk(pp_dt = pp_dt, t_cut = t_cut, fit_cens = fit_cens, lp = lp, w_floor = w_floor)
    theta0_logrr <- base$logrr
    theta0_rd <- base$rd

  } else if (base_estimator == "dr_glm") {
    dr <- fit_dr_risk_rescue(
      pp_dt = pp_dt,
      t_cut = t_cut,
      mis_spec = mis_spec,
      use_ml_Q = dr_use_ml,
      ml_method = ml_method,
      crossfit = crossfit,
      cf_folds = cf_folds,
      seed = seed
    )
    theta0_logrr <- dr$logrr
    theta0_rd <- dr$rd

  } else {
    tm <- fit_tmle_or_dr(pp_dt = pp_dt, t_cut = t_cut, mis_spec = mis_spec)
    theta0_logrr <- tm$logrr
    theta0_rd <- tm$rd
  }

  curve <- anchored_theta_curve(
    pp_dt = pp_dt,
    t_cut = t_cut,
    breaks = breaks,
    delta_grid = delta_grid,
    shape = shape,
    t0 = t0,
    theta0_logrr = theta0_logrr,
    theta0_rd = theta0_rd
  )

  delta_star <- compute_delta_star(delta_grid, curve, measure = "logrr", decision_mode = decision_mode)

  list(delta_star = delta_star, theta0_logrr = theta0_logrr, theta0_rd = theta0_rd)
}
