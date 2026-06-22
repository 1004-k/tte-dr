# TTE-DR minimal input schema

This document describes the minimal public interface recommended for the SoftwareX version of TTE-DR.

## 1. Target-trial metadata

A YAML or CSV configuration file should record:

- `study_id`
- `software_release`
- `estimand`
- `strategy_contrast`
- `follow_up_days`
- `protocol_deviation_rule`
- `analysis_date`
- `primary_output_dir`

## 2. Time-resolved diagnostic input

Suggested columns for `example_time_resolved_diagnostics.csv`:

| Column | Meaning |
|---|---|
| `scenario_id` or `study_id` | analysis identifier |
| `time` | follow-up time on the analysis grid |
| `spd` | selection-pressure diagnostic at time t |
| `rESS` | relative effective sample size at time t |
| `tail_share` | upper-tail weight share at time t |

## 3. Specification-stability input

Suggested columns for `example_specification_estimates.csv`:

| Column | Meaning |
|---|---|
| `specification_id` | primary or pre-specified alternative |
| `log_hr` | effect estimate on log-hazard-ratio scale or another recorded effect scale |
| `se` | standard error if available |
| `note` | design or modeling change represented by the specification |

## 4. Required outputs

A successful TTE-DR run should write:

- `TTE_DR_snapshot_example.pdf`
- `diagnostic_summary.csv`
- `flags.csv`
- `interpretation_text.txt`
- `run_metadata.json`

The manuscript should not claim that the workflow is a consensus standard. It should describe these files as a proposed reusable reporting format and a software-generated diagnostic report.
