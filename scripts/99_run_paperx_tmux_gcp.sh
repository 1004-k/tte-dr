#!/usr/bin/env bash
# GCP/tmux launcher for Paper X (TTE-DR standard)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

tmux kill-session -t px_main 2>/dev/null || true
tmux kill-session -t px_methods 2>/dev/null || true

# common knobs
export T_MAX="${T_MAX:-5}"
export DT="${DT:-0.25}"
export T_CUT="${T_CUT:-5}"
export HORIZON_SET="${HORIZON_SET:-3,4,5}"
export MIS_SPEC_LEVELS="${MIS_SPEC_LEVELS:-0,1}"
export TRUTH_LEVELS="${TRUTH_LEVELS:-null}"
export BETA_TRUE_PP="${BETA_TRUE_PP:-0}"

export DELTA_MAX="${DELTA_MAX:-2.0}"
export DELTA_STEP="${DELTA_STEP:-0.1}"
export DELTA_SHAPE="${DELTA_SHAPE:-late_only}"
export T0_SENS="${T0_SENS:-3.5}"
export DECISION_MODE="${DECISION_MODE:-cross_zero}"

export DELTA_DGM="${DELTA_DGM:-D1_zero}"
export DELTA_MAG="${DELTA_MAG:-0.6}"
export T0_DELTA="${T0_DELTA:-3.5}"
export CORR_MEAS_UNM="${CORR_MEAS_UNM:-0.0}"

export BREAK_DT="${BREAK_DT:-1.0}"
export C_ESS="${C_ESS:-0.25}"
export C_TAIL="${C_TAIL:-0.10}"

# Patterns-style artifacts
export BUILD_REPORT="${BUILD_REPORT:-1}"

# anti oversubscription
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

cat > /tmp/px_main_cmd.sh <<'CMD'
set -euo pipefail
OUT_DIR=${OUT_DIR:-output_paperx_main}
mkdir -p "$OUT_DIR"
export OUT_DIR

export N_CORES=${N_CORES_MAIN:-10}
export B=${B_MAIN:-200}
export N=${N_MAIN:-2000}

Rscript scripts/31_run_paperx_referenceclass.R > "$OUT_DIR/run.log" 2>&1
Rscript scripts/32_make_paperx_tables.R     >> "$OUT_DIR/run.log" 2>&1
Rscript scripts/33_make_paperx_figures.R    >> "$OUT_DIR/run.log" 2>&1

if [ "${BUILD_REPORT:-1}" = "1" ]; then
  Rscript scripts/35_make_patterns_report_md.R  >> "$OUT_DIR/run.log" 2>&1
fi

echo "DONE $(date)" >> "$OUT_DIR/run.log"
CMD
chmod +x /tmp/px_main_cmd.sh

tmux new-session -d -s px_main "cd '$REPO_ROOT' && bash /tmp/px_main_cmd.sh"

tmux ls

echo "To monitor:"
echo "  tail -f output_paperx_main/run.log"

# Optional: methods demo (subset scenarios, compares baseline estimators)
cat > /tmp/px_methods_cmd.sh <<'CMD'
set -euo pipefail
OUT_DIR=${OUT_DIR:-output_paperx_methods}
mkdir -p "$OUT_DIR"
export OUT_DIR

export N_CORES=${N_CORES_METHODS:-6}
export B=${B_METHODS:-50}
export N=${N_METHODS:-2000}
export SCENARIO_SUBSET=${SCENARIO_SUBSET_METHODS:-S01,S09,S18}
export MIS_SPEC_LEVELS=${MIS_SPEC_LEVELS_METHODS:-0}
export EST_SET=${EST_SET:-ipcw,dr_glm,tmle}

Rscript scripts/34_run_paperx_methods_demo.R > "$OUT_DIR/run.log" 2>&1
echo "DONE $(date)" >> "$OUT_DIR/run.log"
CMD
chmod +x /tmp/px_methods_cmd.sh

tmux new-session -d -s px_methods "cd '$REPO_ROOT' && bash /tmp/px_methods_cmd.sh"

echo "To monitor (methods):"
echo "  tail -f output_paperx_methods/run.log"
