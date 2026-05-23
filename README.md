# TTE-DR: target trial emulation diagnostic report generator

This repository contains the simulation and reporting code for TTE-DR, a standardized quality-assurance diagnostic report for per-protocol target trial emulation in observational studies.

TTE-DR is designed as a reporting resource rather than a new causal estimator. It organizes diagnostic evidence into four modules:

1. Pressure: time-varying selection pressure, SPD(t)
2. Positivity: relative effective sample size and upper-tail weight concentration
3. Stability: sensitivity across a pre-specified set of reasonable specifications
4. Sensitivity: residual tipping summary, delta*

The generator produces calibrated grades, dominant flags, continuous diagnostics, a one-page diagnostic snapshot, manuscript-ready figures/tables, and run metadata for audit.

## Repository layout

```text
R/                 Core simulation, diagnostic, grading, and reporting functions
scripts/           Reproducible pipelines and figure/table builders
docs/              STAR Methods skeleton, submission checklist, and run notes
paper_outputs/     Versioned outputs used for the manuscript
  figures/         Figure 1-3, Figure S1, and graphical abstract
  tables/          Table 1, Table 2, and Table S1
  report/          Curated diagnostic snapshot and short report summary
```

## Quick start

From the repository root:

```bash
Rscript scripts/00_install_deps.R
bash scripts/98_quickcheck.sh
```

The quickcheck run uses a small subset of scenarios and writes output to `quickcheck_paperx/`.

## Full reproducibility run

The full manuscript run is intended for a multi-core machine or cloud instance.

```bash
chmod +x scripts/99_run_paperx_tmux_gcp.sh
bash scripts/99_run_paperx_tmux_gcp.sh

tmux ls
tail -f output_paperx_main/run.log
```

Default full-run settings:

```text
B = 200 Monte Carlo replicates
N = 2,000 simulated individuals per replicate
18 reference-class scenarios
truth levels: causal_null by default
nuisance-model levels: well specified and misspecified
```

## Main output files

After a full run, the manuscript-facing files are written under `output_paperx_main/figures/` and `output_paperx_main/tables/`.

Recommended clean submission names are:

```text
Figure_1_TTEDR_grade_heatmap.pdf
Figure_2_reference_class_representatives.pdf
Figure_3_TTEDR_diagnostic_snapshot.pdf
Figure_S1_cutoff_sensitivity.pdf
Graphical_Abstract_TTEDR.pdf
Graphical_Abstract_TTEDR.png
Table_1_reference_class_representatives.csv
Table_2_canonical_slice_summary.csv
Table_S1_full_TTEDR_summary.csv
```

A curated copy of these outputs is provided in `paper_outputs/`.

## Grading and informational notes

TTE-DR separates dominant grading flags from informational notes. Direction changes around the causal null are recorded as informational notes, not automatic warning flags. Residual sensitivity values shown as `>2.0` indicate no tipping within the evaluated range (`delta_max = 2.0`).

## Environment

The code depends on R and common CRAN packages:

```text
R >= 4.2.2
data.table
survival
future
future.apply
```

Each run writes session information and metadata to the output directory for audit.

## Archiving before journal submission

Before submitting the manuscript, create a public GitHub release and archive the release on Zenodo. Then update the manuscript key resources table, reference list, and `CITATION.cff` with:

```text
GitHub release URL
release commit hash
Zenodo DOI
```

## License

MIT License.
