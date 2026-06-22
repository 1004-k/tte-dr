#!/usr/bin/env Rscript
# Minimal smoke test for the SoftwareX submission version of TTE-DR.

script <- file.path('scripts', 'run_ttedr_example.R')
if (!file.exists(script)) stop('Missing example script: ', script, call. = FALSE)

status <- system2('Rscript', script)
if (!identical(status, 0L)) stop('Example script failed with status ', status, call. = FALSE)

expected <- file.path('example_output', c(
  'TTE_DR_snapshot_example.pdf',
  'diagnostic_summary.csv',
  'flags.csv',
  'interpretation_text.txt',
  'run_metadata.json'
))
missing <- expected[!file.exists(expected)]
if (length(missing)) stop('Missing expected outputs: ', paste(missing, collapse = ', '), call. = FALSE)

summary <- read.csv(file.path('example_output', 'diagnostic_summary.csv'), stringsAsFactors = FALSE)
required <- c('study_id', 'scenario_id', 'overall_grade', 'max_abs_spd', 'min_rESS', 'dominant_flags')
if (!all(required %in% names(summary))) stop('diagnostic_summary.csv is missing required columns.', call. = FALSE)
if (!summary$overall_grade[1] %in% c('Green', 'Amber', 'Red')) stop('Unexpected grade value.', call. = FALSE)

message('TTE-DR smoke test passed.')
