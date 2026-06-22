#!/usr/bin/env Rscript
# TTE-DR example run for the SoftwareX submission.
# Public interface demonstrated here: diagnostic inputs + rules -> report outputs.
# This smoke-test example is intentionally dependency-light and uses base R.

script_path <- function() {
  cmd <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep('^--file=', cmd, value = TRUE)
  if (length(file_arg)) return(normalizePath(sub('^--file=', '', file_arg[1]), mustWork = FALSE))
  if (!is.null(sys.frames()[[1]]$ofile)) return(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE))
  normalizePath('scripts/run_ttedr_example.R', mustWork = FALSE)
}

read_simple_config <- function(path) {
  x <- readLines(path, warn = FALSE)
  x <- x[grepl(':', x)]
  keys <- trimws(sub(':.*$', '', x))
  vals <- trimws(sub('^[^:]+:', '', x))
  vals <- gsub('^"|"$', '', vals)
  stats::setNames(as.list(vals), keys)
}

worsen_grade <- function(current, candidate) {
  order <- c(Green = 1, Amber = 2, Red = 3)
  if (order[[candidate]] > order[[current]]) candidate else current
}

root <- normalizePath(file.path(dirname(script_path()), '..'), mustWork = FALSE)
if (!dir.exists(file.path(root, 'example_data'))) root <- getwd()
input_dir <- file.path(root, 'example_data')
output_dir <- file.path(root, 'example_output')
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

required_inputs <- file.path(input_dir, c(
  'example_ttedr_config.yml',
  'example_time_resolved_diagnostics.csv',
  'example_specification_estimates.csv'
))
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs)) {
  stop('Missing required input files: ', paste(missing_inputs, collapse = ', '), call. = FALSE)
}

config <- read_simple_config(required_inputs[1])
dx <- read.csv(required_inputs[2], stringsAsFactors = FALSE)
specs <- read.csv(required_inputs[3], stringsAsFactors = FALSE)

required_dx <- c('scenario_id', 'time', 'spd', 'rESS', 'tail_share')
required_specs <- c('scenario_id', 'specification_id', 'log_hr', 'se', 'note')
if (!all(required_dx %in% names(dx))) stop('Time-resolved diagnostic input is missing required columns.', call. = FALSE)
if (!all(required_specs %in% names(specs))) stop('Specification input is missing required columns.', call. = FALSE)

max_abs_spd <- max(abs(dx$spd), na.rm = TRUE)
end_pressure <- tail(dx$spd, 1) / 0.3875  # illustrative scaling used only for this demo
min_rESS <- min(dx$rESS, na.rm = TRUE)
max_tail_share <- max(dx$tail_share, na.rm = TRUE)
estimate_range <- diff(range(specs$log_hr, na.rm = TRUE))
direction_reversal <- any(specs$log_hr < 0) && any(specs$log_hr > 0)

flags <- character()
grade <- 'Green'

if (max_abs_spd >= 0.80 || end_pressure >= 2.00) {
  grade <- worsen_grade(grade, 'Red')
  flags <- c(flags, 'high_pressure', 'high_cum_pressure', 'extreme_signal')
} else if (max_abs_spd >= 0.50) {
  grade <- worsen_grade(grade, 'Amber')
  flags <- c(flags, 'moderate_pressure')
}
if (min_rESS < 0.70 || max_tail_share >= 0.10) {
  grade <- worsen_grade(grade, 'Red')
  flags <- c(flags, 'positivity_stress')
}
if (estimate_range >= 0.25) {
  grade <- worsen_grade(grade, 'Red')
  flags <- c(flags, 'specification_instability')
}
if (!length(flags)) flags <- 'none'

summary <- data.frame(
  study_id = config$study_id,
  scenario_id = unique(dx$scenario_id)[1],
  overall_grade = grade,
  max_abs_spd = round(max_abs_spd, 3),
  end_pressure = round(end_pressure, 3),
  min_rESS = round(min_rESS, 3),
  max_tail_share = round(max_tail_share, 3),
  estimate_range = round(estimate_range, 3),
  direction_reversal = direction_reversal,
  dominant_flags = paste(flags, collapse = '; '),
  stringsAsFactors = FALSE
)
write.csv(summary, file.path(output_dir, 'diagnostic_summary.csv'), row.names = FALSE)

action_map <- c(
  high_pressure = 'Report time-resolved selection pressure and residual sensitivity.',
  high_cum_pressure = 'Discuss sustained selective adherence over follow-up.',
  extreme_signal = 'Avoid a decision-grade point conclusion without further sensitivity analysis.',
  moderate_pressure = 'Inspect the timing of pressure and report sensitivity analyses.',
  positivity_stress = 'Inspect support, weight tails, and possible support restriction.',
  specification_instability = 'Report the full alternative specification set.',
  none = 'No dominant warning flag crossed the example thresholds.'
)
module_map <- c(
  high_pressure = 'pressure', high_cum_pressure = 'pressure', extreme_signal = 'pressure',
  moderate_pressure = 'pressure', positivity_stress = 'positivity',
  specification_instability = 'stability', none = 'overall'
)
flag_table <- data.frame(
  flag = flags,
  module = unname(module_map[flags]),
  severity = ifelse(flags == 'none', 'Green', grade),
  recommended_action = unname(action_map[flags]),
  stringsAsFactors = FALSE
)
write.csv(flag_table, file.path(output_dir, 'flags.csv'), row.names = FALSE)

interpretation <- paste0(
  'The TTE-DR example report was graded ', grade,
  ' because protocol deviation appeared prognosis-dependent over follow-up. ',
  'Dominant flags: ', paste(flags, collapse = ', '), '. ',
  'The per-protocol estimate should be accompanied by time-resolved diagnostics, ',
  'the full specification-stability table, and residual-sensitivity reporting.'
)
writeLines(interpretation, file.path(output_dir, 'interpretation_text.txt'))

json_lines <- c(
  '{',
  '  "software": "TTE-DR",',
  paste0('  "release": "', config$software_release, '",'),
  '  "script": "scripts/run_ttedr_example.R",',
  '  "input_files": [',
  '    "example_data/example_ttedr_config.yml",',
  '    "example_data/example_time_resolved_diagnostics.csv",',
  '    "example_data/example_specification_estimates.csv"',
  '  ],',
  '  "output_dir": "example_output/",',
  paste0('  "r_version": "', R.version.string, '"'),
  '}'
)
writeLines(json_lines, file.path(output_dir, 'run_metadata.json'))

pdf(file.path(output_dir, 'TTE_DR_snapshot_example.pdf'), width = 8.5, height = 11)
par(mar = c(0, 0, 0, 0))
plot.new()
text(0.05, 0.94, 'TTE-DR diagnostic snapshot', adj = 0, cex = 1.5, font = 2)
text(0.05, 0.89, paste0('Study: ', config$study_id, ' | Grade: ', grade), adj = 0, cex = 1.1)
text(0.05, 0.84, paste0('Dominant flags: ', paste(flags, collapse = '; ')), adj = 0, cex = 0.9)
text(0.05, 0.77, 'Module summaries', adj = 0, cex = 1.1, font = 2)
text(0.08, 0.72, paste0('Pressure: max |SPD(t)| = ', round(max_abs_spd, 3), '; end pressure = ', round(end_pressure, 3)), adj = 0)
text(0.08, 0.67, paste0('Positivity: min rESS = ', round(min_rESS, 3), '; max tail share = ', round(max_tail_share, 3)), adj = 0)
text(0.08, 0.62, paste0('Stability: range across specs = ', round(estimate_range, 3), '; direction reversal = ', direction_reversal), adj = 0)
text(0.08, 0.57, 'Sensitivity: report residual tipping analysis when pressure flags are Red', adj = 0)
text(0.05, 0.48, 'Template interpretation', adj = 0, cex = 1.1, font = 2)
text(0.08, 0.41, interpretation, adj = 0, cex = 0.78)
text(0.05, 0.08, 'Generated by TTE-DR | Script: scripts/run_ttedr_example.R | Output: example_output/', adj = 0, cex = 0.7)
dev.off()

message('TTE-DR example outputs written to: ', output_dir)
