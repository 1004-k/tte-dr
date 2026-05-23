#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR=${OUT_DIR:-quickcheck_paperx}
N_CORES=${N_CORES:-2}
B=${B:-20}
N=${N:-800}
T_MAX=${T_MAX:-4}
DT=${DT:-0.5}
T_CUT=${T_CUT:-2}
MIS_SPEC_LEVELS=${MIS_SPEC_LEVELS:-0}
TRUTH_LEVELS=${TRUTH_LEVELS:-null}
SCENARIO_SUBSET=${SCENARIO_SUBSET:-S01,S04,S10}
HORIZON_SET=${HORIZON_SET:-1,2}
DELTA_MAX=${DELTA_MAX:-1.0}
DELTA_STEP=${DELTA_STEP:-0.2}

export OUT_DIR N_CORES B N T_MAX DT T_CUT MIS_SPEC_LEVELS TRUTH_LEVELS SCENARIO_SUBSET HORIZON_SET DELTA_MAX DELTA_STEP

Rscript scripts/31_run_paperx_referenceclass.R
Rscript scripts/32_make_paperx_tables.R
Rscript scripts/33_make_paperx_figures.R

# Patterns-style artifacts (optional but recommended)
Rscript scripts/35_make_patterns_report_md.R

echo "Quickcheck done. Outputs under: $OUT_DIR"
